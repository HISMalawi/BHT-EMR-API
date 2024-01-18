# frozen_string_literal: true

module TbService
  # A summary of a patient's ART clinic visit
  class PatientVisit
    include ModelUtils

    attr_reader :patient, :date

    def initialize(patient, date)
      @patient = patient
      @date = date
    end

    def guardian_present?
      @guardian_present ||= Observation.where(concept: concept('Guardian Present'),
                                              person: patient.person,
                                              value_coded: concept('Yes').concept_id)\
                                       .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(date))\
                                       .exists?
    end

    def patient_present?
      @patient_present ||= Observation.where(concept: concept('Patient Present'),
                                             person: patient.person,
                                             value_coded: concept('Yes').concept_id)\
                                      .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(date))\
                                      .exists?
    end

    def outcome
      return @outcome if @outcome

      outcome = ActiveRecord::Base.connection.select_one(
        "SELECT patient_outcome(#{patient.id}, DATE('#{date.to_date}')) as outcome"
      )['outcome']

      @outcome = outcome.casecmp?('UNKNOWN') ? 'Unk' : outcome
    end

    def outcome_date
      date
    end

    def next_appointment
      Observation.where(person: patient.person, concept: concept('Appointment date'))\
                 .order(obs_datetime: :desc)\
                 .first\
                 &.value_datetime
    end

    def tb_status
      state = begin
                Concept.find(Observation.where(['person_id = ? AND concept_id = ? AND DATE(obs_datetime) <= ? AND value_coded IS NOT NULL',
                                                patient.id, ConceptName.find_by_name('TB STATUS').concept_id,
                                                visit_date.to_date]).order('obs_datetime DESC, date_created DESC').first.value_coded).fullname
              rescue StandardError
                'Unk'
              end

      program_id = Program.find_by_name('TB PROGRAM').id
      patient_state = PatientState.where(["patient_state.voided = 0 AND p.voided = 0
         AND p.program_id = ? AND DATE(start_date) <= DATE('#{date}') AND p.patient_id =?",
                                          program_id, patient.id]).joins('INNER JOIN patient_program p  ON p.patient_program_id = patient_state.patient_program_id').order('start_date DESC').first

      return state if patient_state.blank?

      ConceptName.find_by_concept_id(patient_state.program_workflow_state.concept_id).name
    end

    def height
      obs = Observation.where(concept: concept('Height (cm)'), person: patient.person)\
                       .order(obs_datetime: :desc)\
                       .first

      obs&.value_numeric || obs&.value_text || 0
    end

    def weight
      obs = Observation.where(concept: concept('Weight'), person: patient.person)\
                       .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(date))\
                       .last

      obs&.value_numeric || obs&.value_text || 0
    end

    def bmi
      obs = Observation.where(concept: concept('BMI'), person_id: patient.patient_id)\
                       .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(date))\
                       .first

      obs&.value_numeric || obs&.value_text || 0
    end

    def adherence
      return @adherence if @adherence

      observations = Observation.where(concept: concept('What was the patients adherence for this drug order'),
                                       person: patient.person)\
                                .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(date))

      @adherence = observations.collect do |observation|
        [observation&.order&.drug_order&.drug&.name || '', observation.value_numeric]
      end
    end

    def pills_brought
      return @pills_brought if @pills_brought

      observations = Observation.where(concept: concept('Amount of drug brought to clinic'),
                                       person: patient.person)\
                                .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(date))

      @pills_brought = observations.collect do |observation|
        drug = observation&.order&.drug_order&.drug
        next unless drug

        [format_drug_name(drug), observation.value_numeric]
      end
    end

    def pills_dispensed
      return @pills_dispensed if @pills_dispensed

      observations = Observation.where(concept: concept('Amount dispensed'),
                                       person: patient.person)\
                                .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(date))

      @pills_dispensed = observations.each_with_object({}) do |observation, pills_dispensed|
        drug = observation&.order&.drug_order&.drug
        next unless drug

        drug_name = format_drug_name(drug)
        pills_dispensed[drug_name] ||= 0
        pills_dispensed[drug_name] += observation.value_numeric
      end

      @pills_dispensed = @pills_dispensed.collect { |k, v| [k, v] }
    end

    def visit_by
      if patient_present? && guardian_present?
        'BOTH'
      elsif patient_present?
        'Patient'
      elsif guardian_present?
        'Guardian'
      else
        'Unk'
      end
    end

    def side_effects
      return @side_effects if @side_effects

      parent_obs = Observation.where(concept: concept('Malawi ART side effects'), person: patient.person)\
                              .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(date))\
                              .order(obs_datetime: :desc)
                              .first
      return [] unless parent_obs

      @side_effects = parent_obs.children\
                                .where(value_coded: concept('Yes'))\
                                .collect { |side_effect| side_effect.concept.fullname }
                                .compact
    end

    def viral_load_result
      lab_tests_engine.find_orders_by_patient(patient).each do |order|
        order.tests.each do |test|
          next unless test[:test_type].match?(/viral load/i)

          values = test[:test_values].collect do |test_value|
            next if test_value[:indicator].match?(/result_date/i)

            test_value[:value]
          end

          values.join(', ')
        end
      end
    rescue StandardError => e
      Rails.logger.error "Failed to retrieve viral load result from LIMS: #{e}"
      'N/A'
    end

    def cpt; end

    private

    def calculate_bmi(weight, height)
      return 'N/A' if weight.zero? || height.zero?

      (weight / (height * height) * 10_000).round(1)
    end

    def format_drug_name(drug)
      match = drug.name.match(/^(.+)\s*\(.*$/)
      name = match.nil? ? drug.name : match[1]

      name = 'CPT' if name.match?('Cotrimoxazole')
      name = 'INH' if name.match?('INH')
      name
    end
  end
end
