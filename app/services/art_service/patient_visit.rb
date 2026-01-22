# frozen_string_literal: true

module ArtService
  # A summary of a patient's ART clinic visit
  class PatientVisit
    LOGGER = Rails.logger
    TIME_EPOCH = '1970-01-01'.to_time

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
      Observation.joins(:encounter)
                 .where(person: patient.person, concept: concept('Appointment date'))\
                 .where('obs_datetime >= ?', date)
                 .where(encounter: { program: Program.find_by(name: 'HIV Program') })
                 .order(obs_datetime: :asc)\
                 .first\
                 &.value_datetime
    end

    def tb_status
      tb_status = PatientState.joins(:patient_program)\
                              .merge(PatientProgram.where(patient:, program: program('tb_program')))\
                              .where('start_date <= ?', date.to_date)\
                              .order(:start_date)\
                              .last\
                              &.name

      return tb_status if tb_status

      tb_status_value = Observation.where(person_id: patient.id, concept: concept('TB Status'))\
                                   .where('DATE(obs_datetime) <= ? AND value_coded IS NOT NULL', date.to_date)\
                                   .order(:obs_datetime)\
                                   .last\
                                   &.value_coded

      return 'Unknown' unless tb_status_value

      ConceptName.find_by(concept_id: tb_status_value, concept_name_type: 'SHORT')&.name || 'Unk'
    end

    def height
      obs = Observation.where(concept: concept('Height (cm)'), person: patient.person)\
                       .where("DATE(obs_datetime) <= DATE('#{@date.to_date}')")
                       .order(obs_datetime: :desc)
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

      @pills_brought = observations.each_with_object([]) do |observation, pills_brought|
        drug = observation&.order&.drug_order&.drug
        next unless drug

        pills_brought << [format_drug_name(drug), observation.value_numeric]
      end
    end

    def pills_dispensed
      return @pills_dispensed if @pills_dispensed

      observations = Observation.where(concept: concept('Amount dispensed'),
                                       person: patient.person)\
                                .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(date))
                                .includes(order: { drug_order: { drug: %i[alternative_names] } })
                                .select(%i[order_id value_numeric])

      @pills_dispensed = observations.each_with_object({}) do |observation, pills_dispensed|
        drug = observation&.order&.drug_order&.drug
        next unless drug

        drug_name = format_drug_name(drug)
        pills_dispensed[drug_name] ||= { drug_name: drug_name, pills_dispensed: 0, runout_date: '' }
        pills_dispensed[drug_name][:pills_dispensed] += observation.value_numeric
        pills_dispensed[drug_name][:runout_date] = observation&.order&.auto_expire_date&.strftime('%d/%b/%Y')
      end

      @pills_dispensed = @pills_dispensed.map { |k, v| v.values }
    end

    def visit_by
      if patient_present? && guardian_present?
        'Patient'
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

      parent_obs = Observation.where(concept: concept('Malawi ART side effects'), person: patient.person)
                              .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(date))
                              .order(obs_datetime: :desc)

      return [] unless parent_obs

      @side_effects = []
      parent_obs.each do |obs|
        result = obs.children
                    .where(value_coded: ConceptName.find_by_name!('Yes').concept_id)
                    .collect { |side_effect| side_effect.concept.fullname }

        @side_effects << result.join(',') unless result.blank?
      end

      @side_effects
    end

    def viral_load_result
      tests = viral_load_tests('<=')

      result = Lab::LabResult.where(obs_group_id: tests, person_id: patient.patient_id)
                             .order(:obs_datetime)
                             .last
      return 'N/A' unless result

      viral_load_concept = ConceptName.where(name: 'HIV Viral Load').select(:concept_id)
      value = result.children.where(concept_id: viral_load_concept).first
      return 'N/A' unless value

      "#{value.value_modifier || '='}#{value.value_numeric || value.value_text}(#{value.obs_datetime.strftime('%d/%b/%y')})"
    end

    def cpt; end

    def regimen
      PatientSummary.new(patient, date).current_regimen
    end

    def as_json(_options = {})
      dispensations = pills_dispensed

      {
        outcome:,
        outcome_date:,
        visit_by:,
        side_effects:,
        viral_load: viral_load_result,
        pills_brought:,
        pills_dispensed: dispensations,
        regimen: dispensations.empty? ? 'N/A' : regimen,
        adherence:,
        tb_status:,
        height:,
        weight:,
        bmi:,
        systolic_blood_pressure:,
        diastolic_blood_pressure:
      }
    end

    private

    def systolic_blood_pressure
      Observation.where(concept: concept('Systolic blood pressure'), person: patient.person)
                 .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(date))
                 .last
                 &.value_numeric
    end

    def diastolic_blood_pressure
      Observation.where(concept: concept('Diastolic blood pressure'), person: patient.person)
                 .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(date))
                 .last
                 &.value_numeric
    end

    def viral_load_tests(sql_params = '=')
      viral_load_concept = ConceptName.where(name: 'HIV Viral Load').select(:concept_id)
      # tests = Lab::LabTest.where(value_coded: viral_load_concept, person_id: patient.patient_id, obs_datetime: Dat)
      Lab::LabTest.where("value_coded IN (#{viral_load_concept.to_sql})
                          AND person_id = #{patient.patient_id}
                          AND DATE(obs_datetime) #{sql_params} '#{date.to_date}'")
    end

    def lab_tests_engine
      @lab_tests_engine = ArtService::LabTestsEngine.new(program: program('HIV Program'))
    end

    def calculate_bmi(weight, height)
      return 'N/A' if weight.zero? || height.zero?

      (weight / (height * height) * 10_000).round(1)
    end

    def format_drug_name(drug)
      short_name = drug.alternative_names.first&.short_name

      return short_name.gsub(/\s+/, '') if short_name.present? && !Drug.arv_drugs.pluck(:drug_id).include?(drug.drug_id)

      if %r{^\d*[A-Z]+\s*\d+(\s*/\s*\d*[A-Z]+\s*\d+)*$}i.match(short_name)
        return short_name.gsub(/\s+/, '')
      end

      drug.name
    end
  end
end
