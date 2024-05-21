# frozen_string_literal: true
require 'set'
require 'date'
require 'yaml'

module TbService
  class TbMdrService
    include ModelUtils
    include TimeUtils

    MDR_STATE_ID = 174
    MINOR_AGE_LIMIT = 14

    _BASE_DIR = 'db/data/ntp'
    REGIMEN_DIFINITIONS_FILE = "#{_BASE_DIR}/dr_regimen_definitions.yml"
    DRUG_DIFINITIONS_FILE = "#{_BASE_DIR}/dr_drug_dictionary.yml"
    CUSTOM_OPTIONS_FILE = "#{_BASE_DIR}/dr_custom_regimen_options.yml"

    def initialize(patient, program, date, starting_date = '1970-01-01')
      @program = program
      @patient = patient
      @date = date
      @starting_date = starting_date
      @regimens = regimen_definitions
      @encounter = get_current_regimen_encounter
      @enrollment_date = regimen_enrollment_date
      @title = get_regimen_name
      @name = format_name(@title)
      @regimen = @regimens[@name]
      @duration = regimen_duration
      @patient_type = get_patient_type
    end

    def status(issues)
      {
        mdr_status: patient_on_mdr_treatment?,
        regimen_title: @regimen['title'],
        regimen_composition: get_regimen_composition,
        next_phase: @regimen['next_phase'],
        fail_state_phase: @regimen['fail_state_phase'],
        duration_in_months: @duration,
        months_on_regimen: get_months_on_regimen,
        end_of_phase: end_of_phase?,
        overdue_examination: overdue_for_examination?,
        resistance_classification: drug_resistance_classification,
        conversion_date: last_conversion_status_date,
        enrolled_on: @enrollment_date,
        conversion_status: has_sputum_conversion?,
        issues: issues,
        regimen_drugs: get_current_regimen_drugs,
        pregnant: pregnant?,
        eptb: eptb?,
        not_risk: treatment_failure_risk?
      }
    end

    def regimen_definitions
      YAML.load_file(REGIMEN_DIFINITIONS_FILE)
    end

    def drug_dictionary
      YAML.load_file(DRUG_DIFINITIONS_FILE)['tb_drugs']
    end

    def custom_regimen_options
      YAML.load_file(CUSTOM_OPTIONS_FILE)
    end

    def get_regimen_status
      return { mdr_status: patient_on_mdr_treatment? } if @regimen.blank?
      issues = validate_regimen_conditions(@regimen)
      mark_regimen_as_failure(issues) if !issues.blank? && !is_regimen_failure?
      status(issues)
    end

    def get_regimens
      return get_regimen_types if is_transfer_in_patient? || !@title.blank?
      regimens = get_regimen_types(true)
      priority_regimen = get_recommended_regimen(regimens)
      regimens[priority_regimen]['primary'] = true if not priority_regimen.nil?
      regimens
    end

    def get_patient_type
      obs = get_obs('Type of patient').order(obs_datetime: :desc).first
      ConceptName.find_by_concept_id(obs.value_coded).name if obs.present?
    end

    def get_regimen_types(all = false)
      regimens = {}
      @regimens.each do |id, regimen|
        next if all && regimen['initial'] != 1
        regimens[id] = regimen
        regimens[id]['primary'] = false
        regimens[id]['issues'] = validate_regimen_conditions(regimen)
      end
      regimens
    end

    def get_recommended_regimen(regimens)
      recommended = nil
      regimens.each do |id, regimen|
        if regimen['priority'] == 1 && regimen['issues'].blank?
          recommended = id
          break
        end
        if regimen['priority'] == 2 && regimen['issues'].blank?
          recommended = id
        end
        if regimen['priority'] == 3 && regimen['issues'].blank? && recommended.nil?
          recommended = id
        end
        if regimen['priority'] == 4 && regimen['issues'].blank? && recommended.nil?
          recommended = id
        end
      end
      recommended
    end

    def get_current_regimen_drugs
      regimen_drugs = @regimen['drugs']
      begin
        return create_drug_payload_from_drug_concepts(get_custom_regimen_drugs)\
                             if regimen_drugs == '_custom_'
        create_drug_payload_from_drug_names(regimen_drugs)
      rescue => exception
        []
      end
    end

    def get_custom_regimen_options
      payload = {}
      options = custom_regimen_options
      options.each do |group, data|
        payload[group] = data
        payload[group]['drugs'] = create_drug_payload_from_drug_names(data['drugs'])
      end
      return payload
    end

    def create_drug_payload_from_drug_names(drug_names)
      drug_names.map do |drug_name|
        metadata = get_drug_metadata(drug_name)
        drug = Drug.get_concept_drugs(metadata['concept'].concept_id)
        metadata['drug'] = {
          weight_adjusted: adjust_drug_by_weight_band(drug),
          raw_drug: drug
        }
        drug_concept_ids = drug.map(&:concept_id)
        metadata['resistant'] = is_resistant_to(drug_concept_ids)
        metadata['side_effects'] = has_drug_induced_intorelance(drug_concept_ids)
        metadata['substitute'] = get_drug_metadata(metadata['substitute'])
        metadata
      end
    end

    def create_drug_payload_from_drug_concepts(drug_concepts)
        payload = []
        drug_concepts.each do |drug_concept|
          metadata = get_drug_metadata(drug_concept.name, false)
          drug = Drug.get_concept_drugs(drug_concept.concept_id)
          metadata['concept'] = drug_concept
          metadata['drug'] = {
            weight_adjusted: adjust_drug_by_weight_band(drug),
            raw_drug: drug
          }
          metadata['resistant'] = is_resistant_to(drug_concept.concept_id)
          metadata['side_effects'] = has_drug_induced_intorelance(drug_concept.concept_id)
          metadata['substitute'] = get_drug_metadata(metadata['substitute'])
          payload << metadata
        end
        payload
    end

    def get_drug_metadata(drug, can_add_concept = true)
      begin
        drug_metadata = drug_dictionary[drug]
        drug_metadata['concept'] = ConceptName.find_by(name: drug) if can_add_concept
        return drug_metadata
      rescue StandardError
        {}
      end
    end

    def adjust_drug_by_weight_band(drugs)
      begin
        patient = Patient.find_by(patient_id: @patient)
        weight = patient.weight.blank? ? 0 : patient.weight.floor
        NtpRegimen.adjust_weight_band(drugs, weight)
      rescue StandardError
        []
      end
    end

    def format_name(name)
      name.tr(' ','_').downcase if not name.nil?
    end

    def get_regimen_name
      name = get_current_regimen_type
      name.value_text if not name.blank?
    end

    def regimen_duration
      begin
        return get_custom_regimen_duration if individualised_regimen?
        @regimen['duration']
      rescue => exception
        0
      end
    end

    def go_to_next_phase
      issues = validate_regimen_conditions(@regimen)

      if !issues.blank? && !@regimen['fail_state_phase'].blank?

        create_regimen(@regimen['fail_state_phase'])
      elsif issues.blank? && !@regimen['next_phase'].blank?

        create_regimen(@regimen['next_phase'])
      end
    end

    def mark_regimen_as_failure(reasons = ['None'])
      encounter = update_regimen_encounter
      ObservationService.new.create_observation(encounter, {
        person: Person.find(@patient),
        concept: concept('Regimen failure'),
        value_text: @title,
        obs_datetime: @date
      })
      create_regimen_failure_reasons(encounter, reasons)
    end

    def create_regimen_failure_reasons(encounter, reasons)
      reasons.each do |reason|
        ObservationService.new.create_observation(encounter, {
          person: Person.find(@patient),
          concept: concept('Reason tuberculosis treatment changed or stopped'),
          value_text: reason,
          obs_datetime: @date
        })
      end
    end

    def is_regimen_failure?
      get_obs('Regimen failure').where(value_text: @title).present?
    end

    def no_regimen_failure_history(regimen_name)
      get_obs('Regimen failure')\
              .where(value_text: regimen_name)
              .order(obs_datetime: :desc)
              .first
              .blank?
    end

    def new_regimen(regimen_name)
      return nil if not @regimens.include? regimen_name
      regimen = @regimens[regimen_name]
      issues = validate_regimen_conditions(regimen)
      return { issues: issues } if not issues.empty?
      create_regimen(regimen_name)
    end

    def get_regimen_composition
      return get_custom_regimen_composition if individualised_regimen?
      @regimen['regimen_composition']
    end

    def get_custom_regimen_composition
      obs = get_obs('Regimen composition')\
              .where(encounter: @encounter)
              .where('obs_datetime >= ?', @enrollment_date)
              .order(obs_datetime: :desc)
              .first
      return obs.value_text if obs.present?
    end

    def create_regimen(regimen_name, date = nil)
      regimen = !@regimens[regimen_name].blank? ? @regimens[regimen_name]['title'] : regimen_name
      encounter = create_regimen_encounter
      obs = create_regimen_obs(regimen, encounter, date)

      { encounter: encounter, obs: obs }
    end

    def create_regimen_obs(regimen_title, encounter, date = nil)
      obs_date = date.nil? ? @date: date
      regimen_type = concept('Regimen type')
      obs =  {
        person: Person.find(@patient),
        concept: regimen_type,
        value_text: regimen_title,
        obs_datetime: obs_date
      }
      # Record a date to continue MDR treatment where transfer in patient left off
      if !@title && is_transfer_in_patient? && transfer_in_treatment_start_date
        obs[:value_datetime] = transfer_in_treatment_start_date
      end

      ObservationService.new.create_observation(encounter, obs)
    end

    def create_custom_regimen(drugs, duration = 0, code = '')
      regimen = create_regimen('individualised_regimen')

      encounter = regimen[:encounter]

      medications = add_custom_regimen_drugs(encounter, drugs)

      duration_obs = create_custom_duration(encounter, duration)

      code_obs = create_regimen_composition_code(encounter, code) if not code.empty?

      { regimen: regimen, duration: duration_obs, drugs: medications, code: code_obs }
    end

    def create_custom_duration(encounter, duration)
      ObservationService.new.create_observation(
        encounter, {
        person: Person.find(@patient),
        concept: concept('Regimen duration in months'),
        value_numeric: duration,
        obs_datetime: @date
      })
    end

    def create_regimen_composition_code(encounter, composition)
      ObservationService.new.create_observation(
        encounter, {
        person: Person.find(@patient),
        concept: concept('Regimen composition'),
        value_text: composition,
        obs_datetime: @date
      })
    end

    def add_custom_regimen_drugs(encounter, drugs)
      drugs.each do |drug|
        ObservationService.new.create_observation(encounter, {
          concept: concept('Medication'),
          value_coded: drug,
          person: Person.find(@patient),
          obs_datetime: @date
        })
      end
    end

    def get_custom_regimen_drugs
      obs = get_obs_with_encounter('REGIMEN INITIAL', 'Medication')
                      .where(encounter: @encounter)
                      .where('obs_datetime >= ?', @enrollment_date)
      if obs.present?
          return ConceptName.where(concept_id: obs.map(&:value_coded), concept_name_type: 'FULLY_SPECIFIED')
      end
      []
    end

    def get_custom_regimen_duration
      return if @encounter.nil?
      obs = get_obs('Regimen duration in months')\
                .where(encounter: @encounter)
                .where('obs_datetime >= ?', @enrollment_date)
                .order(obs_datetime: :desc)
                .first
      return obs.value_numeric if not obs.blank?
    end

    def update_regimen_encounter
      encounter = EncounterService.new
      encounter.create(
        patient: Patient.find(@patient),
        program: Program.find(@program),
        type: encounter_type('REGIMEN CHANGE'),
        encounter_datetime: @date
      )
    end

    def create_regimen_encounter
      encounter = EncounterService.new
      encounter.create(
        patient: Patient.find(@patient),
        program: Program.find(@program),
        type: encounter_type('REGIMEN INITIAL'),
        encounter_datetime: @date
      )
    end

    def validate_regimen_conditions(regimen)
      issues = []
      regimen['conditions'].each do |criteria|
          if not criteria['param'].nil?
            evaluated = method(criteria['condition']).call(criteria['param'])
          else
            evaluated = method(criteria['condition']).call
          end

          next if evaluated.nil?

          # Fire exception to the rule if it exists... The exception to the rule must alway evaluate to true
          # inorder to ignore issues raised by the primary condition
          if !evaluated.nil? && !criteria['exceptional'].nil?
            evaluated_exceptional_condition = method(criteria['exceptional']).call
            next if evaluated_exceptional_condition
          end

          issues << criteria['fail'] if evaluated != criteria['expected']
      end
      issues
    end

    def is_mono_resistant?
      type_of = get_obs('Resistance classification').order(obs_datetime: :desc).first
      type_of.value_coded === concept('Mono resistant').concept_id if type_of.present?
    end

    def is_transfer_in_patient?
      @patient_type == 'Transfer in MDR-TB patient'
    end

    def is_multi_drug_resistant?
      type_of = get_obs('Resistance classification').order(obs_datetime: :desc).first
      type_of.value_coded == concept('Multi drug resistant').concept_id if type_of.present?
    end

    def patient_on_mdr_treatment?
      PatientState.joins(:patient_program)\
                  .where(patient_program: {program_id: @program,
                                             patient_id: @patient})
                  .where(state: MDR_STATE_ID, end_date: nil)
                  .where('DATE(start_date) <= DATE(?)', @date)
                  .first
                  .present?
    end

    def get_current_regimen_encounter
      get_obs_with_encounter('REGIMEN INITIAL', 'Regimen type').order(obs_datetime: :desc).first
    end

    def get_current_regimen_type
      get_obs('Regimen type').order(obs_datetime: :desc).first
    end

    def get_duration_with_current_date(datetime)
      (Date.parse(@date.to_s)-Date.parse(datetime.strftime('%F'))).to_i
    end

    def get_months_on_regimen
      current_date = Date.parse(@date.to_s)
      enrollment_date = Date.parse(@enrollment_date.strftime('%F'))
      regimen_duration = (current_date-enrollment_date).to_i
      (regimen_duration/28)
    end

    def regimen_enrollment_date
      begin
        regimen = get_current_regimen_type
        return regimen.value_datetime if not regimen.value_datetime.nil?
        regimen.obs_datetime
      rescue StandardError
        nil
      end
    end

    def drug_resistance_classification
       begin
          obs = get_obs('Resistance classification').order(obs_datetime: :desc).first
          ConceptName.where(concept_id: obs.value_coded).first.name
       rescue StandardError
          'N/A'
       end
    end

    def end_of_phase?
      begin
        get_months_on_regimen >= @duration
      rescue => exception
        false
      end
    end

    def individualised_regimen?
      @name == 'individualised_regimen'
    end

    def negative_after_end_of_phase?
      begin
        end_of_phase? ? has_sputum_conversion?(true) : nil
      rescue
        nil
      end
    end

    # Patients achieve conversion when two consecutive tests are negative
    def has_sputum_conversion?(allow_positive_for_second_result = false)
        negative = concept('Negative').concept_id

        obs = get_obs('TB status', false).order(obs_datetime: :desc).limit(2)

        first_result = false
        second_result = false

        first_result = obs[0].value_coded == negative if obs.present?

        second_result = obs[1].value_coded == negative if obs.present? && obs.length >= 2

        (first_result && second_result || allow_positive_for_second_result && first_result && !second_result)
    end

    def is_resistant_to(drugs)
      begin
        get_obs('TB drug resistance').where(value_coded:drugs.map(&:concept_id)).present?
      rescue => exception
        false
      end
    end

    def has_drug_induced_intorelance(drugs)
      begin
        get_obs('Drug induced').where(value_drug: drugs).present?
      rescue => exception
        false
      end
    end

    def hiv?
      obs = get_obs('Hiv status', false).order(obs_datetime: :desc).first
      obs.present? ? obs.value_coded == concept('Positive').concept_id : false
    end

    def minor?
      person = Person.find_by(person_id: @patient)
      ((Time.zone.now - person.birthdate.to_time) / 1.year.seconds).floor < MINOR_AGE_LIMIT
    end

    def eptb?
      obs = get_obs('Type of tuberculosis').order(obs_datetime: :desc).first
      obs.present? ? obs.value_coded == concept('Extrapulmonary tuberculosis (EPTB)').concept_id : false
    end

    def pregnant?
      obs = get_obs('Patient pregnant').order(obs_datetime: :desc).first
      obs.present? ? obs.value_coded == concept('Yes').concept_id : false
    end

    def treatment_failure_risk?
      patient_types = ['Relapse', 'Treatment Failure', 'Return after lost to follow up']
      patient_type_concepts = ConceptName.select(:concept_id).distinct.where(name: patient_types)
      get_obs('Type of patient', false).where(value_coded: patient_type_concepts).present?
    end

    def on_other_regimen_for_more_than_amonth?(regimen_name)
       begin
         regimen_name != @title && get_months_on_regimen >= 1
       rescue StandardError
         false
       end
    end

    def has_resistance_to_custom_drugs?
      begin
        is_resistant_to(get_custom_regimen_drugs)
      rescue StandardError
        false
      end
    end

    def has_resistance_to_drugs?(drugs)
      drug_concepts = ConceptName.where(name: drugs, concept_name_type: 'FULLY_SPECIFIED')
      is_resistant_to(drug_concepts)
    end

    def is_a_contact_of_person_resistant_to_drugs?(drugs)
      begin
        drug_concepts = ConceptName.where(name: drugs, concept_name_type: 'FULLY_SPECIFIED')
        index_cases = get_drug_resistant_indexes(drug_concepts.map(&:concept_id))
        is_drug_resistant_contact(index_cases)
      rescue StandardError
        false
      end
    end

    def get_drug_resistant_indexes(drugs)
      indexes = Observation.where(concept: concept('TB drug resistance'), value_coded: drugs)
                           .where.not(person_id: @patient)
      indexes.map(&:person_id) if not indexes.blank?
    end

    def is_drug_resistant_contact(index_cases)
        relationship_type = RelationshipType.find_by(a_is_to_b: 'TB patient')
        Relationship.where(
          type: relationship_type,
          person_a: index_cases,
          person_b: @patient
        ).present?
    end

    def check_if_currently_on_different_regimen_than(regimens)
      return false if @name.nil? || regimens.include?(@name)
      true
    end

    def overdue_for_examination?
      !mdr_transfer_in_today? && (no_lab_order_exists? || last_lab_order_is_thirty_days_ago?)
    end

    def last_lab_order_is_thirty_days_ago?
      obs = get_obs_with_encounter('LAB ORDERS', 'Test requested', false).order(obs_datetime: :desc).first
      obs.present? ? get_duration_with_current_date(obs.obs_datetime) >= 28 : false
    end

    def no_lab_order_exists?
      get_obs_with_encounter('LAB ORDERS', 'Test requested', false).blank?
    end

    def last_conversion_status_date
      query = get_obs('TB status', false).order(obs_datetime: :desc).first
      return query.obs_datetime if not query.blank?
    end

    def transfer_in_treatment_start_date
      obs = get_obs('Multidrug-resistant TB treatment start date')
              .order(obs_datetime: :desc)
              .first
      obs.value_datetime if obs.present?
    end

    def mdr_transfer_in_today?
      get_obs('Type of patient')
            .where(value_coded: concept('Transfer in MDR-TB patient').concept_id)
            .where('DATE(obs_datetime) = DATE(?)', @date)
            .order(obs_datetime: :desc)
            .first
            .present?
    end

    def get_obs(concept_name, use_start_date = true)
      query_set = Observation.where(person_id: @patient)
                             .where(concept: concept(concept_name))
                             .where('DATE(obs_datetime) <= DATE(?)', @date)
      query_set = query_set.where('obs_datetime >= ?', @starting_date) if use_start_date
      return query_set
    end

    def get_obs_with_encounter(encounter_name, concept_name, use_start_date = true)
      query_set = Observation.joins(:encounter)
                             .where(encounter: {
                                    type: encounter_type(encounter_name),
                                    patient_id: @patient,
                                    program_id: @program})
                            .where(concept: concept(concept_name))
                            .where('DATE(obs_datetime) <= DATE(?)', @date)
      query_set = query_set.where('obs_datetime >= ?', @starting_date) if use_start_date
      return query_set
    end

  end
end
