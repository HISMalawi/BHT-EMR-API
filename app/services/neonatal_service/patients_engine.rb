# frozen_string_literal: true

module NeonatalService
  ##
  # Handles patient-centric operations for neonatal service
  #
  # This engine provides:
  # - Patient data retrieval
  # - Patient summaries
  # - Encounter history
  # - Patient searches and filters
  class PatientsEngine
    include ModelUtils

    attr_reader :program

    LOGGER = Rails.logger

    def initialize(program:)
      @program = program
    end

    ##
    # Gets full patient summary
    #
    # @param patient_id [Integer] Patient ID
    # @param date [Date] Date for the summary
    # @return [Hash] Full patient summary
    def patient(patient_id, date = Date.today)
      patient = Patient.find(patient_id)
      patient_summary(patient, date).full_summary
    end

    ##
    # Gets list of encounters saved for patient on a given date
    #
    # @param patient [Patient] Patient object
    # @param date [Date] Date to check
    # @return [Array<String>] Array of encounter type names
    def saved_encounters(patient, _date = nil)
      patient_id = patient.patient_id || patient.id

      Encounter.joins(:type)
               .where(program_id: @program.program_id, patient_id: patient_id, voided: 0)
               .order(:encounter_datetime)
               .pluck('encounter_type.name')
               .uniq
    end

    ##
    # Gets all patients enrolled in neonatal program
    #
    # @param filters [Hash] Optional filters
    # @option filters [Date] :date Date filter
    # @option filters [Integer] :page Page number for pagination
    # @option filters [Integer] :per_page Records per page
    # @return [ActiveRecord::Relation]
    def enrolled_patients(filters = {})
      relation = PatientProgram.joins(:patient)
                               .where(program_id: @program.program_id)

      relation = relation.where('date_enrolled <= ?', filters[:date]) if filters[:date]
      relation = relation.where('date_completed IS NULL OR date_completed >= ?', filters[:date] || Date.today)

      paginate(relation, filters[:page], filters[:per_page])
    end

    ##
    # Searches for neonatal patients
    #
    # @param search_params [Hash] Search parameters
    # @option search_params [String] :name Patient name
    # @option search_params [String] :identifier Patient identifier
    # @option search_params [Date] :date_enrolled Enrollment date
    # @return [ActiveRecord::Relation]
    def search_patients(search_params = {})
      relation = PatientProgram.joins(:patient)
                               .where(program_id: @program.program_id)

      if search_params[:name].present?
        name_query = "%#{search_params[:name]}%"
        relation = relation.joins('INNER JOIN person_name ON person_name.person_id = patient.patient_id')
                           .where('person_name.given_name LIKE ? OR person_name.family_name LIKE ?',
                                  name_query, name_query)
      end

      if search_params[:identifier].present?
        relation = relation.joins('INNER JOIN patient_identifier ON patient_identifier.patient_id = patient.patient_id')
                           .where('patient_identifier.identifier LIKE ?', "%#{search_params[:identifier]}%")
      end

      if search_params[:date_enrolled].present?
        relation = relation.where('DATE(date_enrolled) = ?', search_params[:date_enrolled].to_date)
      end

      relation.distinct
    end

    ##
    # Gets patients who visited on a specific date
    #
    # @param date [Date] Visit date
    # @return [Array<Patient>]
    def patients_visited_on(date)
      Patient.joins(:encounters)
             .where('encounter.program_id = ?', @program.program_id)
             .where('DATE(encounter.encounter_datetime) = ?', date.to_date)
             .distinct
    end

    ##
    # Gets patients with appointments on a specific date
    #
    # @param date [Date] Appointment date
    # @return [Array<Hash>] Patient appointments
    def patients_with_appointments_on(date)
      appointment_type = encounter_type('APPOINTMENT')
      return [] unless appointment_type

      appointments = Observation.joins(:encounter, :concept)
                                .where('encounter.program_id = ?', @program.program_id)
                                .where('encounter.encounter_type = ?', appointment_type.encounter_type_id)
                                .where('concept.concept_id = ?', concept('Appointment date')&.concept_id)
                                .where('DATE(obs.value_datetime) = ?', date.to_date)
                                .select('obs.*, encounter.*')

      appointments.map do |appointment|
        {
          patient_id: appointment.encounter.patient_id,
          patient: Patient.find(appointment.encounter.patient_id),
          appointment_date: appointment.value_datetime,
          encounter_id: appointment.encounter_id
        }
      end
    end

    STAT_STATUSES = {
      enrolled: 'In patient',
      admitted: 'Admitted',
      discharged: 'Discharged',
      critical: 'Critical',
      triage_only: 'Triage Only - Pending Registration'
    }.freeze

    ##
    # Gets patient statistics with drill down data for landing page cards
    # @param date [Date] Date for statistics
    # @return [Hash] Statistics hash
    def statistics(date = Date.today)
      {
        enrolled: build_statistic_from_programs(patients_enrolled_on(date), date, STAT_STATUSES[:enrolled]),
        admitted: build_statistic(patients_admitted_on(date), date, STAT_STATUSES[:admitted]),
        discharged: build_statistic_from_programs(patients_discharged_on(date), date, STAT_STATUSES[:discharged]),
        critical: build_statistic(critical_patients(date), date, STAT_STATUSES[:critical]),
        triage_only: build_statistic(triage_only_patients(date), date, STAT_STATUSES[:triage_only]),
        recent_neonates: get_recent_neonates(date)
      }
    end

    ##
    # Gets recent neonates based on recent encounters
    # Returns neonates (babies ≤ 28 days old enrolled in neonatal program) with encounters in the last 7 days
    #
    # @param date [Date] Reference date (defaults to today)
    # @param limit [Integer] Maximum number of neonates to return (default: 10)
    # @return [Array<Hash>] Array of formatted neonate data
    def get_recent_neonates(date = Date.today, limit = 10)
      start_date = date.to_date - 7.days
      end_date = date.to_date

      # Get unique neonates (babies ≤ 28 days old) with NEONATAL encounters in the last 7 days
      # Filter by:
      # 1. Enrolled in neonatal program
      # 2. Age ≤ 28 days (neonatal period) - CRITICAL to exclude mothers
      # 3. Has encounters in the last 7 days
      recent_patients = Encounter
        .select('patient.*, person.birthdate, MAX(encounter.encounter_datetime) as last_encounter_time')
        .joins(:patient)
        .joins('INNER JOIN person ON person.person_id = patient.patient_id')
        .joins("INNER JOIN patient_program ON patient_program.patient_id = patient.patient_id
                AND patient_program.program_id = #{@program.program_id}
                AND patient_program.voided = 0
                AND (patient_program.date_completed IS NULL OR patient_program.date_completed >= '#{date.to_date}')")
        .where('encounter.program_id = ?', @program.program_id)
        .where('encounter.voided = ?', 0)
        .where('DATE(encounter.encounter_datetime) BETWEEN ? AND ?', start_date, end_date)
        .where('person.birthdate IS NOT NULL')
        .where('DATEDIFF(?, person.birthdate) <= ?', date.to_date, 28)
        .group('patient.patient_id')
        .order('last_encounter_time DESC')
        .limit(limit)
        .map(&:patient)
        .compact

      # Format neonates with appropriate status
      recent_patients.map do |patient|
        status = determine_patient_status(patient, date)
        format_neonate(patient, status, date)
      end
    end

    ##
    # Determines the current status of a patient
    #
    # @param patient [Patient]
    # @param date [Date]
    # @return [String] Patient status
    def determine_patient_status(patient, date)
      # Check if patient is discharged
      program = PatientProgram.find_by(
        patient_id: patient.patient_id,
        program_id: @program.program_id
      )

      return STAT_STATUSES[:discharged] if program && program.date_completed && program.date_completed <= date

      # Check if patient has critical/emergency triage
      triage_concept = concept('Triage priority')
      emergency_value = concept('Emergency')

      if triage_concept && emergency_value
        has_emergency = Observation
          .joins(:encounter)
          .where(encounter: { patient_id: patient.patient_id, program_id: @program.program_id, voided: 0 })
          .where(voided: 0, concept_id: triage_concept.concept_id, value_coded: emergency_value.concept_id)
          .where('DATE(obs_datetime) >= ?', date - 1.day)
          .exists?

        return STAT_STATUSES[:critical] if has_emergency
      end

      admission_encounter_names = [
        'NEONATAL SIGNS & SYMPTOMS',
        'NEONATAL REVIEW OF SYSTEMS',
        'PHYSICAL EXAMINATION BABY',
        'NEONATAL GENERAL EXAMINATION',
        'VITALS',
        'NEONATAL VITALS',
        'NEONATAL SYSTEMIC EXAMINATION'
      ]

      encounter_types = EncounterType.where(name: admission_encounter_names)
      if encounter_types.any?
        has_admission_encounter_today = Encounter
          .where(patient_id: patient.patient_id, program_id: @program.program_id)
          .where(encounter_type: encounter_types.pluck(:encounter_type_id), voided: 0)
          .where('DATE(encounter_datetime) = ?', date)
          .exists?

        return STAT_STATUSES[:admitted] if has_admission_encounter_today
      end

      # Default to enrolled/in patient
      STAT_STATUSES[:enrolled]
    end

    ##
    # Gets total enrolled patients up to a date
    #
    # @param date [Date]
    # @return [Integer]
    def total_enrolled_patients(date = Date.today)
      PatientProgram.where(program_id: @program.program_id)
                    .where('date_enrolled <= ?', date)
                    .count
    end

    ##
    # Gets patients enrolled on a specific date
    #
    # @param date [Date]
    # @return [ActiveRecord::Relation]
    def patients_enrolled_on(date)
      PatientProgram.joins(:patient)
                    .where(program_id: @program.program_id)
                    .where('DATE(date_enrolled) = ?', date.to_date)
                    .includes(patient: { person: :names })
    end

    ##
    # Gets patients discharged on specific date
    #
    # @param date [Date]
    # @return [ActiveRecord::Relation]
    def patients_discharged_on(date)
      PatientProgram.joins(:patient)
                    .where(program_id: @program.program_id)
                    .where.not(date_completed: nil)
                    .where('DATE(date_completed) = ?', date.to_date)
                    .includes(patient: { person: :names })
    end

    ##
    # Gets active patients (enrolled and not completed)
    #
    # @param date [Date]
    # @return [ActiveRecord::Relation]
    def active_patients(date = Date.today)
      PatientProgram.joins(:patient)
                    .where(program_id: @program.program_id)
                    .where('date_enrolled <= ?', date)
                    .where('date_completed IS NULL OR date_completed >= ?', date)
    end

    ##
    # Gets patient's next appointment
    #
    # @param patient [Patient]
    # @return [Hash, nil] Appointment details or nil
    def next_appointment(patient)
      appointment_type = encounter_type('APPOINTMENT')
      return nil unless appointment_type

      appointment_obs = Observation.joins(:encounter)
                                   .where('encounter.patient_id = ?', patient.patient_id)
                                   .where('encounter.program_id = ?', @program.program_id)
                                   .where('encounter.encounter_type = ?', appointment_type.encounter_type_id)
                                   .where('encounter.concept_id = ?', concept('Appointment date')&.concept_id)
                                   .where('obs.value_datetime >= ?', Date.today)
                                   .order('obs.value_datetime ASC')
                                   .first

      return nil unless appointment_obs

      {
        appointment_date: appointment_obs.value_datetime,
        encounter_id: appointment_obs.encounter_id,
        days_until_appointment: (appointment_obs.value_datetime.to_date - Date.today).to_i
      }
    end

    ##
    # Gets patient visit history
    #
    # @param patient [Patient]
    # @param limit [Integer] Number of visits to return
    # @return [Array<Hash>] Visit history
    def visit_history(patient, limit = 10)
      Encounter.where(patient_id: patient.patient_id, program_id: @program.program_id)
               .order(encounter_datetime: :desc)
               .limit(limit)
               .group_by { |e| e.encounter_datetime.to_date }
               .map do |date, encounters|
        {
          date: date,
          encounters: encounters.map { |e| { type: e.type.name, id: e.encounter_id } }
        }
      end
    end

    ##
    # Gets patient labels/alerts
    #
    # @param patient [Patient]
    # @param date [Date]
    # @return [Array<String>] Array of label strings
    def patient_labels(patient, date = Date.today)
      labels = []

      # Check if patient is enrolled
      unless enrolled?(patient)
        labels << 'NOT ENROLLED'
        return labels
      end

      # Check age
      age_in_days = (date - patient.birthdate).to_i
      if age_in_days > 28
        labels << 'BEYOND NEONATAL PERIOD'
      elsif age_in_days <= 7
        labels << 'EARLY NEONATAL'
      else
        labels << 'LATE NEONATAL'
      end

      # Check if patient has appointments
      next_appt = next_appointment(patient)
      if next_appt
        if next_appt[:days_until_appointment].zero?
          labels << 'APPOINTMENT TODAY'
        elsif next_appt[:days_until_appointment] < 0
          labels << 'MISSED APPOINTMENT'
        elsif next_appt[:days_until_appointment] <= 7
          labels << "APPOINTMENT IN #{next_appt[:days_until_appointment]} DAYS"
        end
      end

      # Check if visited today
      labels << 'VISITED TODAY' if visited_today?(patient, date)

      labels
    end

    private

    ##
    # Creates a patient summary object
    #
    # @param patient [Patient]
    # @param date [Date]
    # @return [PatientSummary]
    def patient_summary(patient, date)
      NeonatalService::PatientSummary.new(patient, date, @program)
    end

    ##
    # Fetches neonates who went through at least one encounter of the admission workflow on a date
    # Admission workflow encounters: NEONATAL SIGNS & SYMPTOMS, NEONATAL REVIEW OF SYSTEMS,
    # PHYSICAL EXAMINATION BABY, NEONATAL GENERAL EXAMINATION, VITALS, NEONATAL VITALS,
    # NEONATAL SYSTEMIC EXAMINATION
    #
    # @param date [Date]
    # @return [Array<Patient>]
    def patients_admitted_on(date)
      admission_encounter_names = [
        'NEONATAL SIGNS & SYMPTOMS',
        'NEONATAL REVIEW OF SYSTEMS',
        'PHYSICAL EXAMINATION BABY',
        'NEONATAL GENERAL EXAMINATION',
        'VITALS',
        'NEONATAL VITALS',
        'NEONATAL SYSTEMIC EXAMINATION'
      ]

      encounter_types = EncounterType.where(name: admission_encounter_names)
      return [] if encounter_types.empty?

      Encounter.where(program_id: @program.program_id, encounter_type: encounter_types.pluck(:encounter_type_id), voided: 0)
               .where('DATE(encounter_datetime) = ?', date.to_date)
               .includes(:patient)
               .map(&:patient)
               .compact
               .uniq { |patient| patient.patient_id }
    end

    ##
    # Fetches neonates with emergency triage priority for a date
    #
    # @param date [Date]
    # @return [Array<Patient>]
    def critical_patients(date)
      triage_concept = concept('Triage priority')
      emergency_value = concept('Emergency')
      return [] unless triage_concept && emergency_value

      Observation.joins(:encounter)
                 .where(encounter: { program_id: @program.program_id, voided: 0 })
                 .where(voided: 0)
                 .where(concept_id: triage_concept.concept_id, value_coded: emergency_value.concept_id)
                 .where('DATE(obs_datetime) = ?', date.to_date)
                 .includes(encounter: :patient)
                 .map { |obs| obs.encounter.patient }
                 .compact
                 .uniq { |patient| patient.patient_id }
    end

    ##
    # Fetches patients who had NEONATAL_TRIAGE encounters but have minimal/incomplete registration
    # These are patients created during emergency triage without full registration
    # Identified by having minimal demographics (birthdate_estimated = 1 AND gender = 'U')
    # AND only having NEONATAL_TRIAGE encounter (no other encounters indicating full admission)
    #
    # @param date [Date]
    # @return [Array<Patient>]
    def triage_only_patients(date)
      triage_encounter_type = EncounterType.find_by(name: 'NEONATAL TRIAGE')
      return [] unless triage_encounter_type

      # Get all patients with NEONATAL TRIAGE encounters on the date
      patients_with_triage = Encounter
        .where(program_id: @program.program_id, encounter_type: triage_encounter_type.encounter_type_id, voided: 0)
        .where('DATE(encounter_datetime) = ?', date.to_date)
        .includes(:patient)
        .map(&:patient)
        .compact
        .uniq { |patient| patient.patient_id }

      # Filter to only those with minimal demographics (created via emergency triage)
      # These patients have:
      # 1. birthdate_estimated = 1 (estimated/temporary birthdate)
      # 2. gender = 'U' (Unknown gender)
      # 3. ONLY triage encounter (no enrollment/admission encounters)
      patients_with_triage.select do |patient|
        person = patient.person
        next false unless person

        # Check if has minimal demographics (created via emergency triage)
        has_minimal_demographics = person.birthdate_estimated == 1 && person.gender == 'U'
        next false unless has_minimal_demographics

        # Check if patient ONLY has NEONATAL_TRIAGE encounter (no other neonatal encounters)
        # Exclude patients who also have enrollment or other encounters
        other_encounter_types = [
          'NEONATAL ENROLLMENT',
          'NEONATAL SIGNS & SYMPTOMS',
          'NEONATAL REVIEW OF SYSTEMS',
          'PHYSICAL EXAMINATION BABY',
          'NEONATAL GENERAL EXAMINATION',
          'NEONATAL VITALS',
          'NEONATAL SYSTEMIC EXAMINATION'
        ]

        encounter_types = EncounterType.where(name: other_encounter_types)
        has_other_encounters = Encounter
          .where(patient_id: patient.patient_id, program_id: @program.program_id, voided: 0)
          .where(encounter_type: encounter_types.pluck(:encounter_type_id))
          .exists?

        # Include only if patient has NO other encounters (truly triage-only)
        !has_other_encounters
      end
    end

    def build_statistic_from_programs(program_relation, date, status)
      patients = program_relation.map(&:patient).compact
      build_statistic(patients, date, status)
    end

    def build_statistic(patients, date, status)
      unique_patients = patients.compact.uniq { |patient| patient.patient_id }
      {
        count: unique_patients.length,
        neonates: unique_patients.map { |patient| format_neonate(patient, status, date) }
      }
    end

    def format_neonate(patient, status, date)
      person = patient.person
      {
        id: patient.patient_id,
        name: formatted_name(person),
        mrn: patient_identifier_value(patient),
        age: format_age(person, date),
        weight: format_weight(patient, date),
        status: status
      }
    end

    def formatted_name(person)
      return 'Unknown Neonate' unless person

      name = person.names.first
      parts = [name&.given_name, name&.middle_name, name&.family_name].compact.map(&:strip).reject(&:blank?)
      value = parts.join(' ')
      value.present? ? value : 'Unknown Neonate'
    end

    def patient_identifier_value(patient)
      identifier = patient.national_id
      return identifier if identifier.present?

      patient.patient_identifiers.order(:date_created).last&.identifier || 'N/A'
    end

    def format_age(person, date)
      return 'Unknown' unless person&.birthdate

      reference_date = date.to_date
      age_days = (reference_date - person.birthdate).to_i
      return 'Today' if age_days.zero?
      return "#{age_days} day#{'s' unless age_days == 1} old" if age_days.positive? && age_days < 30

      weeks = (age_days / 7.0).floor
      if weeks.positive? && weeks < 4
        "#{weeks} week#{'s' unless weeks == 1} old"
      else
        "#{age_days} day#{'s' unless age_days == 1} old"
      end
    end

    def format_weight(patient, date)
      value = patient.weight(today: date)
      return nil unless value

      format('%.2f Kg', value)
    end

    ##
    # Checks if patient is enrolled in the program
    #
    # @param patient [Patient]
    # @return [Boolean]
    def enrolled?(patient)
      PatientProgram.where(
        patient_id: patient.patient_id,
        program_id: @program.program_id
      ).where('date_completed IS NULL OR date_completed >= ?', Date.today)
       .exists?
    end

    ##
    # Checks if patient visited today
    #
    # @param patient [Patient]
    # @param date [Date]
    # @return [Boolean]
    def visited_today?(patient, date)
      Encounter.where(patient_id: patient.patient_id, program_id: @program.program_id)
               .where('DATE(encounter_datetime) = ?', date.to_date)
               .exists?
    end

    ##
    # Paginates a relation
    #
    # @param relation [ActiveRecord::Relation]
    # @param page [Integer]
    # @param per_page [Integer]
    # @return [ActiveRecord::Relation]
    def paginate(relation, page = nil, per_page = nil)
      return relation unless page && per_page

      offset = (page.to_i - 1) * per_page.to_i
      relation.offset(offset).limit(per_page.to_i)
    end
  end
end
