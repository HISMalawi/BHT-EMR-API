# frozen_string_literal: true

require 'json'
require 'date'

def extract_patients
  # Get patients enrolled in HIV Program
  hiv_program = Program.find_by_name('HIV PROGRAM')
  
  if hiv_program.nil?
    puts [].to_json
    return
  end

  # ============================================================================
  # DYNAMIC DEFAULTER DETECTION
  # This database does NOT reliably write static PatientState records for defaulters.
  # The EMR report calculates defaulters dynamically using the patient_outcome()
  # MySQL stored function (drug pickup date + quantity/dose + 60 days).
  # We replicate that exact logic here.
  # ============================================================================

  # 1. Get ALL enrolled HIV patient IDs
  enrolled_ids = PatientProgram.where(program_id: hiv_program.id, voided: 0)
                               .pluck(:patient_id).uniq

  if enrolled_ids.empty?
    puts [].to_json
    return
  end

  # 2. Use the patient_outcome() stored function to classify each patient dynamically.
  #    We process in batches to avoid overwhelming the DB with one massive query.
  defaulted_ids = []
  active_ids = []
  reference_date = Date.today.to_s

  enrolled_ids.each_slice(500) do |batch|
    # Build a UNION query that calls patient_outcome() for each patient in the batch
    union_sql = batch.map { |pid| "SELECT #{pid} AS patient_id, patient_outcome(#{pid}, '#{reference_date}') AS outcome" }.join(" UNION ALL ")
    
    results = ActiveRecord::Base.connection.select_all(union_sql)
    results.each do |row|
      pid = row['patient_id'].to_i
      outcome = row['outcome'].to_s

      if outcome.match?(/Defaulted/i)
        defaulted_ids << pid
      elsif outcome.match?(/On antiretrovirals/i)
        active_ids << pid
      end
    end
  end

  # 3. Balance the dataset: Sample up to 250 from each group
  defaulted_sample = defaulted_ids.shuffle.first(250)
  active_sample = active_ids.shuffle.first(250)

  # Combine and shuffle for training
  patients = Patient.where(patient_id: defaulted_sample + active_sample)
                    .includes(:person, :encounters, :orders, patient_programs: :patient_states)
                    .to_a.shuffle

  dataset = []

  # Map generic concepts for features
  side_effect_names = ['Drug side effect', 'ART side effect', 'Malaria severity', 'Symptom present']
  side_effect_concept = ConceptName.where(name: side_effect_names).first&.concept_id
  psych_concept = ConceptName.find_by_name('Mental status')&.concept_id

  # Appointment date concept — used to calculate days_overdue feature
  appointment_concept_id = ConceptName.find_by_name('Appointment date')&.concept_id

  # Pre-compute defaulter dates for cutoff window calculation
  defaulter_dates = {}
  defaulted_sample.each_slice(500) do |batch|
    union_sql = batch.map { |pid| "SELECT #{pid} AS patient_id, current_defaulter_date(#{pid}, '#{reference_date}') AS defaulter_date" }.join(" UNION ALL ")
    results = ActiveRecord::Base.connection.select_all(union_sql)
    results.each do |row|
      pid = row['patient_id'].to_i
      defaulter_dates[pid] = row['defaulter_date']&.to_date
    end
  end

  patients.each do |patient|
    # 1. Determine the exact outcome using the stored function classification
    is_defaulted = defaulted_sample.include?(patient.id) ? 1.0 : 0.0

    # Prevent Target Leakage and Training-Serving Skew:
    # Instead of shifting the cutoff date by a fixed 90 days (which forces days_overdue
    # to always be negative for defaulted patients), we simulate realistic clinical snapshots.
    # A patient is declared a defaulter 30 days after their scheduled return date.
    # We choose a random cutoff date around their scheduled return date (from 30 days before to 25 days after)
    # to evaluate their features at the time of risk.
    if is_defaulted == 1.0 && defaulter_dates[patient.id]
      scheduled_return = defaulter_dates[patient.id] - 30.days
      cutoff_date = scheduled_return + rand(-30..25).days
    else
      # For active patients, we simulate evaluating them at a random time in the last 2 months
      # to ensure they have a realistic distribution of overdue/not-yet-due days.
      cutoff_date = Date.today - rand(0..60).days
    end

    # Define a strict 6-month observation window leading up to that cutoff
    start_window = cutoff_date - 6.months

    # 2. Calculate Age safely relative to the cutoff date
    birthdate = patient.person.birthdate
    age = birthdate ? ((cutoff_date - birthdate.to_date).to_i / 365.25).to_f : 30.0

    # 3. STRICTLY SCOPED COUNTS (Fixes Survivorship Bias)
    recent_encounters = patient.encounters.where(encounter_datetime: start_window.beginning_of_day..cutoff_date.end_of_day)
    recent_orders = patient.orders.where(start_date: start_window.beginning_of_day..cutoff_date.end_of_day)
    
    obs_model = defined?(Observation) ? Observation : Obs
    recent_obs = obs_model.where(person_id: patient.id, obs_datetime: start_window.beginning_of_day..cutoff_date.end_of_day)

    # 4. Feature Proxies for the ML model (Now scoped strictly to the 6-month window)
    visit_consistency = recent_encounters.count.to_f
    side_effects = side_effect_concept ? recent_obs.where(concept_id: side_effect_concept).count.to_f : 0.0
    concurrent_drugs = recent_orders.count.to_f
    psychological_symptoms = psych_concept ? recent_obs.where(concept_id: psych_concept).count.to_f : 0.0

    # 5. MMD-AWARE SCHEDULING SIGNAL (Calculated relative to historical cutoff)
    # This prevents punishing stable patients on 3-6 month dispensing cycles.
    days_overdue = 0.0
    if appointment_concept_id
      # Find the most recent appointment observation recorded BEFORE the cutoff date
      last_appointment = obs_model.where(person_id: patient.id, concept_id: appointment_concept_id)
                                  .where('obs_datetime <= ?', cutoff_date.end_of_day)
                                  .order(obs_datetime: :desc)
                                  .first

      if last_appointment&.value_datetime
        scheduled_return = last_appointment.value_datetime.to_date
        # Positive = overdue relative to cutoff, Negative = not yet due relative to cutoff
        days_overdue = (cutoff_date - scheduled_return).to_f
      end
    end

    dataset << {
      age: age,
      visit_count: visit_consistency,
      side_effects: side_effects,
      concurrent_drugs: concurrent_drugs,
      psychological_symptoms: psychological_symptoms,
      days_overdue: days_overdue,
      label_defaulted: is_defaulted
    }
  end

  # Stream directly to standard output for Python to capture
  puts dataset.to_json
end

extract_patients