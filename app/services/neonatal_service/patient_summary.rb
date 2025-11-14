# frozen_string_literal: true

module NeonatalService
  ##
  # Generates comprehensive patient summaries for neonatal patients
  #
  # Aggregates patient demographics, enrollment data, vitals,
  # clinical observations, and visit history into a single summary
  class PatientSummary
    include ModelUtils

    attr_reader :patient, :date, :program

    def initialize(patient, date, program = nil)
      @patient = patient
      @date = date
      @program = program || Program.find_by_name('Neonatal program')
    end

    ##
    # Returns full patient summary
    #
    # @return [Hash] Complete patient summary
    def full_summary
      {
        patient_id: @patient.patient_id,
        demographics: demographics,
        enrollment: enrollment_info,
        vitals: latest_vitals,
        triage: latest_triage,
        assessments: recent_assessments,
        treatments: recent_treatments,
        appointments: appointment_info,
        visit_summary: visit_summary,
        labels: patient_labels
      }
    end

    ##
    # Returns patient demographics
    #
    # @return [Hash]
    def demographics
      person = @patient.person
      names = person.names.first

      {
        patient_id: @patient.patient_id,
        given_name: names&.given_name,
        family_name: names&.family_name,
        middle_name: names&.middle_name,
        gender: person.gender,
        birthdate: person.birthdate,
        birthdate_estimated: person.birthdate_estimated,
        age_in_days: age_in_days,
        age_in_hours: age_in_hours,
        identifiers: patient_identifiers,
        addresses: patient_addresses,
        attributes: patient_attributes
      }
    end

    ##
    # Returns enrollment information
    #
    # @return [Hash, nil]
    def enrollment_info
      patient_program = PatientProgram.find_by(
        patient_id: @patient.patient_id,
        program_id: @program.program_id,
        date_completed: nil
      )

      return nil unless patient_program

      {
        patient_program_id: patient_program.patient_program_id,
        date_enrolled: patient_program.date_enrolled,
        location_id: patient_program.location_id,
        enrollment_encounter: enrollment_encounter_summary
      }
    end

    ##
    # Returns latest vitals
    #
    # @return [Hash, nil]
    def latest_vitals
      vitals_encounter = latest_encounter('VITALS')
      return nil unless vitals_encounter

      observations = encounter_observations(vitals_encounter)

      {
        encounter_id: vitals_encounter.encounter_id,
        encounter_datetime: vitals_encounter.encounter_datetime,
        weight: find_observation_value(observations, 'Weight (kg)'),
        height: find_observation_value(observations, 'Height (cm)'),
        temperature: find_observation_value(observations, 'Temperature (C)'),
        pulse: find_observation_value(observations, 'Pulse'),
        respiratory_rate: find_observation_value(observations, 'Respiratory rate'),
        systolic_bp: find_observation_value(observations, 'Systolic blood pressure'),
        diastolic_bp: find_observation_value(observations, 'Diastolic blood pressure'),
        spo2: find_observation_value(observations, 'SPO2')
      }
    end

    ##
    # Returns latest triage information
    #
    # @return [Hash, nil]
    def latest_triage
      triage_encounter = latest_encounter('NEONATAL TRIAGE')
      return nil unless triage_encounter

      observations = encounter_observations(triage_encounter)

      {
        encounter_id: triage_encounter.encounter_id,
        encounter_datetime: triage_encounter.encounter_datetime,
        priority: find_observation_value(observations, 'Triage priority'),
        chief_complaint: find_observation_value(observations, 'Chief complaint'),
        observations: format_observations(observations)
      }
    end

    ##
    # Returns recent assessments
    #
    # @param limit [Integer] Number of assessments to return
    # @return [Array<Hash>]
    def recent_assessments(limit = 5)
      assessment_encounters = recent_encounters('ASSESSMENT', limit)

      assessment_encounters.map do |encounter|
        observations = encounter_observations(encounter)

        {
          encounter_id: encounter.encounter_id,
          encounter_datetime: encounter.encounter_datetime,
          diagnosis: find_observation_values(observations, 'Diagnosis'),
          observations: format_observations(observations)
        }
      end
    end

    ##
    # Returns recent treatments
    #
    # @param limit [Integer] Number of treatments to return
    # @return [Array<Hash>]
    def recent_treatments(limit = 5)
      treatment_encounters = recent_encounters('TREATMENT', limit)

      treatment_encounters.map do |encounter|
        observations = encounter_observations(encounter)

        {
          encounter_id: encounter.encounter_id,
          encounter_datetime: encounter.encounter_datetime,
          medications: find_observation_values(observations, 'Medication orders'),
          procedures: find_observation_values(observations, 'Procedures'),
          observations: format_observations(observations)
        }
      end
    end

    ##
    # Returns appointment information
    #
    # @return [Hash]
    def appointment_info
      {
        last_appointment: last_appointment,
        next_appointment: next_appointment
      }
    end

    ##
    # Returns visit summary for today
    #
    # @return [Hash]
    def visit_summary
      {
        date: @date,
        visited: visited_today?,
        encounters_today: encounters_today,
        next_encounter: next_encounter_type
      }
    end

    ##
    # Returns patient labels/alerts
    #
    # @return [Array<String>]
    def patient_labels
      patients_engine.patient_labels(@patient, @date)
    end

    private

    ##
    # Gets patient age in days
    #
    # @return [Integer]
    def age_in_days
      (@date.to_date - @patient.birthdate.to_date).to_i
    end

    ##
    # Gets patient age in hours
    #
    # @return [Integer]
    def age_in_hours
      age_in_days * 24
    end

    ##
    # Gets patient identifiers
    #
    # @return [Array<Hash>]
    def patient_identifiers
      @patient.patient_identifiers.map do |identifier|
        {
          identifier: identifier.identifier,
          identifier_type: identifier.type.name,
          preferred: identifier.preferred == 1
        }
      end
    end

    ##
    # Gets patient addresses
    #
    # @return [Array<Hash>]
    def patient_addresses
      @patient.person.addresses.map do |address|
        {
          city_village: address.city_village,
          state_province: address.state_province,
          country: address.country,
          address1: address.address1,
          address2: address.address2
        }
      end
    end

    ##
    # Gets patient attributes
    #
    # @return [Hash]
    def patient_attributes
      attributes = {}

      @patient.person.person_attributes.each do |attr|
        attributes[attr.type.name] = attr.value
      end

      attributes
    end

    ##
    # Gets enrollment encounter summary
    #
    # @return [Hash, nil]
    def enrollment_encounter_summary
      enrollment_encounter = latest_encounter('NEONATAL ENROLLMENT')
      return nil unless enrollment_encounter

      observations = encounter_observations(enrollment_encounter)

      {
        encounter_id: enrollment_encounter.encounter_id,
        encounter_datetime: enrollment_encounter.encounter_datetime,
        observations: format_observations(observations)
      }
    end

    ##
    # Gets latest encounter of a specific type
    #
    # @param type_name [String] Encounter type name
    # @return [Encounter, nil]
    def latest_encounter(type_name)
      Encounter.joins(:type)
               .where('encounter_type.name = ?', type_name)
               .where(patient_id: @patient.patient_id, program_id: @program.program_id)
               .order(encounter_datetime: :desc)
               .first
    end

    ##
    # Gets recent encounters of a specific type
    #
    # @param type_name [String] Encounter type name
    # @param limit [Integer] Number of encounters
    # @return [Array<Encounter>]
    def recent_encounters(type_name, limit = 5)
      Encounter.joins(:type)
               .where('encounter_type.name = ?', type_name)
               .where(patient_id: @patient.patient_id, program_id: @program.program_id)
               .order(encounter_datetime: :desc)
               .limit(limit)
    end

    ##
    # Gets observations for an encounter
    #
    # @param encounter [Encounter]
    # @return [Array<Observation>]
    def encounter_observations(encounter)
      Observation.where(encounter_id: encounter.encounter_id)
                 .includes(:concept)
                 .order(obs_datetime: :desc)
    end

    ##
    # Finds observation value by concept name
    #
    # @param observations [Array<Observation>]
    # @param concept_name [String]
    # @return [Object, nil]
    def find_observation_value(observations, concept_name)
      obs = observations.find do |observation|
        observation.concept.concept_names.any? { |name| name.name == concept_name }
      end

      return nil unless obs

      extract_observation_value(obs)
    end

    ##
    # Finds all observation values by concept name
    #
    # @param observations [Array<Observation>]
    # @param concept_name [String]
    # @return [Array]
    def find_observation_values(observations, concept_name)
      matching_obs = observations.select do |observation|
        observation.concept.concept_names.any? { |name| name.name == concept_name }
      end

      matching_obs.map { |obs| extract_observation_value(obs) }
    end

    ##
    # Extracts value from observation
    #
    # @param obs [Observation]
    # @return [Object]
    def extract_observation_value(obs)
      if obs.value_coded
        concept_name = Concept.find(obs.value_coded).concept_names.first&.name
        { concept_id: obs.value_coded, name: concept_name }
      elsif obs.value_numeric
        obs.value_numeric
      elsif obs.value_text
        obs.value_text
      elsif obs.value_datetime
        obs.value_datetime
      elsif obs.value_drug
        Drug.find(obs.value_drug).name
      end
    end

    ##
    # Formats observations into structured hash
    #
    # @param observations [Array<Observation>]
    # @return [Array<Hash>]
    def format_observations(observations)
      observations.map do |obs|
        {
          obs_id: obs.obs_id,
          concept_id: obs.concept_id,
          concept_name: obs.concept.concept_names.first&.name,
          value: extract_observation_value(obs),
          obs_datetime: obs.obs_datetime
        }
      end
    end

    ##
    # Gets last appointment
    #
    # @return [Hash, nil]
    def last_appointment
      appointment_encounter = Encounter.joins(:type)
                                       .where('encounter_type.name = ?', 'APPOINTMENT')
                                       .where(patient_id: @patient.patient_id, program_id: @program.program_id)
                                       .where('encounter_datetime <= ?', @date)
                                       .order(encounter_datetime: :desc)
                                       .first

      return nil unless appointment_encounter

      appointment_date_obs = Observation.joins(:concept)
                                        .where(encounter_id: appointment_encounter.encounter_id)
                                        .where('concept.name = ?', 'Appointment date')
                                        .first

      {
        encounter_id: appointment_encounter.encounter_id,
        scheduled_date: appointment_date_obs&.value_datetime,
        created_date: appointment_encounter.encounter_datetime
      }
    end

    ##
    # Gets next appointment
    #
    # @return [Hash, nil]
    def next_appointment
      patients_engine.next_appointment(@patient)
    end

    ##
    # Checks if patient visited today
    #
    # @return [Boolean]
    def visited_today?
      Encounter.where(patient_id: @patient.patient_id, program_id: @program.program_id)
               .where('DATE(encounter_datetime) = ?', @date.to_date)
               .exists?
    end

    ##
    # Gets encounters for today
    #
    # @return [Array<String>]
    def encounters_today
      Encounter.joins(:type)
               .where(patient_id: @patient.patient_id, program_id: @program.program_id)
               .where('DATE(encounter_datetime) = ?', @date.to_date)
               .pluck('encounter_type.name')
               .uniq
    end

    ##
    # Gets next encounter type in workflow
    #
    # @return [String, nil]
    def next_encounter_type
      workflow_engine.next_encounter&.name
    end

    ##
    # Gets workflow engine
    #
    # @return [WorkflowEngine]
    def workflow_engine
      @workflow_engine ||= NeonatalService::WorkflowEngine.new(
        patient: @patient,
        program: @program,
        date: @date
      )
    end

    ##
    # Gets patients engine
    #
    # @return [PatientsEngine]
    def patients_engine
      @patients_engine ||= NeonatalService::PatientsEngine.new(program: @program)
    end
  end
end
