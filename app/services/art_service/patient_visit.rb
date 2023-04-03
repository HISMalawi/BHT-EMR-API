# frozen_string_literal: true

module ARTService
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
                              .merge(PatientProgram.where(patient: patient, program: program('tb_program')))\
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
        pills_dispensed[drug_name] ||= 0
        pills_dispensed[drug_name] += observation.value_numeric
      end

      @pills_dispensed = @pills_dispensed.collect { |k, v| [k, v] }
    end

    def cpt_dispensed
      return @cpt_dispensed if @cpt_dispensed

      cpt_drugs = Drug.where(concept_id: 916).collect(&:drug_id)

      observations = Observation.where(concept: concept('Amount dispensed'), person: patient.person, value_drug: cpt_drugs)
                                .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(date))
                                .includes(order: { drug_order: { drug: %i[alternative_names] } })
                                .select(%i[order_id value_numeric])

      @cpt_dispensed = observations.each_with_object({}) do |observation, cpt_dispensed|
        drug = observation&.order&.drug_order&.drug
        next unless drug

        drug_name = format_drug_name(drug)
        cpt_dispensed[drug_name] ||= 0
        cpt_dispensed[drug_name] += observation.value_numeric
      end

      @cpt_dispensed = @cpt_dispensed.collect { |k, v| [k, v] }
    end

    def arvs_dispensed
      return @arv_dispensed if @arv_dispensed

      arv_drugs = Drug.arv_drugs.collect(&:drug_id)

      observations = Observation.where(concept: concept('Amount dispensed'), person: patient.person, value_drug: arv_drugs)
                                .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(date))
                                .includes(order: { drug_order: { drug: %i[alternative_names] } })
                                .select(%i[order_id value_numeric])

      @arv_dispensed = observations.each_with_object({}) do |observation, arv_dispensed|
        drug = observation&.order&.drug_order&.drug
        next unless drug

        drug_name = format_drug_name(drug)
        arv_dispensed[drug_name] ||= 0
        arv_dispensed[drug_name] += observation.value_numeric
      end

      @arv_dispensed = @arv_dispensed.collect { |k, v| [k, v] }
    end

    def pyridoxine_dispensed
      return @pyridoxine_dispensed if @pyridoxine_dispensed

      pyridoxine_drugs = Drug.where(concept_id: 766).collect(&:drug_id)

      observations = Observation.where(concept: concept('Amount dispensed'), person: patient.person, value_drug: pyridoxine_drugs)
                                .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(date))
                                .includes(order: { drug_order: { drug: %i[alternative_names] } })
                                .select(%i[order_id value_numeric])

      @pyridoxine_dispensed = observations.each_with_object({}) do |observation, pyridoxine_dispensed|
        drug = observation&.order&.drug_order&.drug
        next unless drug

        drug_name = format_drug_name(drug)
        pyridoxine_dispensed[drug_name] ||= 0
        pyridoxine_dispensed[drug_name] += observation.value_numeric
      end

      @pyridoxine_dispensed = @pyridoxine_dispensed.collect { |k, v| [k, v] }
    end

    def inh_dispensed
      return @inh_dispensed if @inh_dispensed

      inh_drugs = Drug.where(concept_id: %w[656 750]).collect(&:drug_id)

      observations = Observation.where(concept: concept('Amount dispensed'), person: patient.person, value_drug: inh_drugs)
                                .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(date))
                                .includes(order: { drug_order: { drug: %i[alternative_names] } })
                                .select(%i[order_id value_numeric])

      @inh_dispensed = observations.each_with_object({}) do |observation, inh_dispensed|
        drug = observation&.order&.drug_order&.drug
        next unless drug

        drug_name = format_drug_name(drug)
        inh_dispensed[drug_name] ||= 0
        inh_dispensed[drug_name] += observation.value_numeric
      end

      @inh_dispensed = @inh_dispensed.collect { |k, v| [k, v] }
    end

    def rfp_dispensed
      return @rfp_dispensed if @rfp_dispensed

      rfp_drugs = Drug.where(concept_id: 9974).collect(&:drug_id)
      observations = Observation.where(concept: concept('Amount dispensed'), person: patient.person, value_drug: rfp_drugs)
                                .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(date))
                                .includes(order: { drug_order: { drug: %i[alternative_names] } })
                                .select(%i[order_id value_numeric])

      @rfp_dispensed = observations.each_with_object({}) do |observation, rfp_dispensed|
        drug = observation&.order&.drug_order&.drug
        next unless drug

        drug_name = format_drug_name(drug)
        rfp_dispensed[drug_name] ||= 0
        rfp_dispensed[drug_name] += observation.value_numeric
      end

      @rfp_dispensed = @rfp_dispensed.collect { |k, v| [k, v] }
    end

    def new_3hp_dispensed
      return @new_3hp_dispensed if @new_3hp_dispensed

      new_3hp_drugs = Drug.where(concept_id: 10_565).collect(&:drug_id)

      observations = Observation.where(concept: concept('Amount dispensed'), person: patient.person, value_drug: new_3hp_drugs)
                                .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(date))
                                .includes(order: { drug_order: { drug: %i[alternative_names] } })
                                .select(%i[order_id value_numeric])

      @new_3hp_dispensed = observations.each_with_object({}) do |observation, new_3hp_dispensed|
        drug = observation&.order&.drug_order&.drug
        next unless drug

        drug_name = format_drug_name(drug)
        new_3hp_dispensed[drug_name] ||= 0
        new_3hp_dispensed[drug_name] += observation.value_numeric
      end

      @new_3hp_dispensed = @new_3hp_dispensed.collect { |k, v| [k, v] }
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

    def pregnant?
      pregnant_concept = ConceptName.where(name: 'pregnant?').select(:concept_id)

      unless Observation.where(concept_id: pregnant_concept, obs_datetime: @date.to_date, value_coded: ConceptName.find_by_name!('Yes').concept_id)
        'Y'
      end
      'N'
    end

    def breastfeeding?
      breastfeeding_concept = ConceptName.where(name: 'breatfeeding?').select(:concept_id)

      unless Observation.where(concept_id: breastfeeding_concept, obs_datetime: @date.to_date, value_coded: ConceptName.find_by_name!('Yes').concept_id)
        'Bf'
      end
    end

    def doses_missed?
      doses_missed_concept = ConceptName.where(name: 'Missed antiretroviral drug construct').select(:concept_id)
      
      doses_missed = Observation.where(concept_id: doses_missed_concept, obs_datetime: @date.to_date, value_coded: ConceptName.find_by_name!('Yes').concept_id )
      
      return if doses_missed.blank?

      doses_missed.first(:value_numeric)
      return doses_missed.first(:value_numeric)
    end

    def last_vl_test
      
    end

    def as_json(_options = {})
      dispensations = pills_dispensed

      {
        outcome: outcome,
        outcome_date: outcome_date,
        visit_by: visit_by,
        side_effects: side_effects,
        viral_load: viral_load_result,
        pills_brought: pills_brought,
        pills_dispensed: dispensations,
        regimen: dispensations.empty? ? 'N/A' : regimen,
        adherence: adherence,
        tb_status: tb_status,
        height: height,
        weight: weight,
        bmi: bmi,
        pregnant: pregnant?,
        breastfeeding: breastfeeding?,
        side_effects_batch: side_effects.empty? ? 'N' : 'Y',next_appointment: next_appointment ? next_appointment.strftime("%Y-%m-%d %H:%M:%S") : nil,
        doses_missed: doses_missed?,
        cpt: cpt_dispensed,
        inh: inh_dispensed,
        rfp: rfp_dispensed,
        inh_rfp: new_3hp_dispensed,
        pryidoxine: pyridoxine_dispensed,
        arvs: arvs_dispensed,
        qtr: @date.month < 4 ? 1 : @date.month < 7 ? 2 : @date.month < 10 ? 3 : 4
      }
    end

    # load the lab results for the given test name
    def lab_result(test_name)
      concept_id = ConceptName.where(name: test_name).select(:concept_id)
      return 'N/A' unless concept_id

      tests = lab_test(concept_id)

      result = Lab::LabResult.where(obs_group_id: tests, person_id: patient.patient_id)
                             .order(:obs_datetime)

      return 'N/A' unless result

      result.collect do |r|
        value = r.children.first

        return 'N/A' unless value

        {
          name: test_name,
          result_date: value.obs_datetime.strftime('%d/%b/%y').to_s,
          result: "#{value.value_modifier || '='}#{value.value_numeric || value.value_text}"
        }
      end
    end

    private

    def viral_load_tests(sql_params = '=')
      viral_load_concept = ConceptName.where(name: 'HIV Viral Load').select(:concept_id)
      # tests = Lab::LabTest.where(value_coded: viral_load_concept, person_id: patient.patient_id, obs_datetime: Dat)
      Lab::LabTest.where("value_coded IN (#{viral_load_concept.to_sql})
                          AND person_id = #{patient.patient_id}
                          AND DATE(obs_datetime) #{sql_params} '#{date.to_date}'")
    end

    def lab_test(test_name_concept_id)
      Lab::LabTest.where(value_coded: test_name_concept_id, person_id: patient.patient_id)
                  .where("DATE(obs_datetime) >= '#{date.to_date.beginning_of_day}'")
    end

    def lab_tests_engine
      @lab_tests_engine = ARTService::LabTestsEngine.new(program: program('HIV Program'))
    end

    def calculate_bmi(weight, height)
      return 'N/A' if weight.zero? || height.zero?

      (weight / (height * height) * 10_000).round(1)
    end

    def format_drug_name(drug)
      moh_name = drug.alternative_names.first&.short_name

      if moh_name && %r{^\d*[A-Z]+\s*\d+(\s*/\s*\d*[A-Z]+\s*\d+)*$}i.match(moh_name)
        return moh_name.gsub(/\s+/, '')
                       .gsub(/Isoniazid/i, 'INH')
      end

      match = drug.name.match(/^(.+)\s*\(.*$/)
      name = match.nil? ? drug.name : match[1]

      name = 'CPT' if name.match?('Cotrimoxazole')
      # name = 'INH' if name.match?('INH')
      name
    end
  end
end
