# frozen_string_literal: true

require "set"

module CxcaService
  class WorkflowEngine
    include ModelUtils

    def initialize(program:, patient:, date:)
      @patient = patient
      @program = program
      @date = date
    end

    # Retrieves the next encounter for bound patient
    def next_encounter
      state = INITIAL_STATE
      loop do
        state = next_state state
        break if state == END_STATE

        LOGGER.debug "Loading encounter type: #{state}"
        encounter_type = EncounterType.find_by(name: state)

        return encounter_type if valid_state?(state)
      end

      nil
    end

    private

    LOGGER = Rails.logger

    # Encounter types
    INITIAL_STATE = 0 # Start terminal for encounters graph
    END_STATE = 1 # End terminal for encounters graphCxCa_TEST = 'CXCA TEST'
    CXCA_RECEPTION = "CXCA RECEPTION"
    CXCA_TEST = "CXCA TEST"
    CXCA_SCREENING_RESULTS = "CXCA screening result"
    CANCER_TREATMENT = "CxCa treatment"
    APPOINTMENT = "APPOINTMENT"

    # Encounters graph
    ENCOUNTER_SM = {
      INITIAL_STATE => CXCA_TEST,
      CXCA_TEST => CXCA_SCREENING_RESULTS,
      CXCA_SCREENING_RESULTS => CANCER_TREATMENT,
      CANCER_TREATMENT => APPOINTMENT,
      APPOINTMENT => END_STATE,
    }.freeze

    STATE_CONDITIONS = {
      CXCA_TEST => %i[show_cxca_test?],
      CXCA_SCREENING_RESULTS => %i[show_cxca_screening_results? offer_cxca_screening?],
      CANCER_TREATMENT => %i[show_cancer_treatment? offer_cxca_screening?],
      APPOINTMENT => %i[show_appointment? offer_cxca_screening? patient_has_not_been_referred?],
    }.freeze
=begin
    STATE_CONDITIONS = {
      CXCA_TEST => %i[show_cxca_test?],
      CXCA_SCREENING_RESULTS => %i[show_cxca_screening_results?],
      CANCER_TREATMENT => %i[show_cancer_treatment?],
      APPOINTMENT => %i[show_appointment?]
    }.freeze
=end

    def next_state(current_state)
      ENCOUNTER_SM[current_state]
    end

    # Check if a relevant encounter of given type exists for given patient.
    #
    # NOTE: By `relevant` above we mean encounters that matter in deciding
    # what encounter the patient should go for in this present time.
    def encounter_exists?(type)
      Encounter.where(type: type, patient: @patient, program: @program).where("encounter_datetime BETWEEN ? AND ?", *TimeUtils.day_bounds(@date)).exists?
    end

    def valid_state?(state)
      return false if encounter_exists?(encounter_type(state))

      (STATE_CONDITIONS[state] || []).reduce(true) do |status, condition|
        status && method(condition).call
      end
    end

    private

    def patient_has_not_been_referred?
      encounter_type = EncounterType.find_by name: CXCA_SCREENING_RESULTS
      tx_option = ConceptName.find_by_name("Directly observed treatment option").concept_id
      tx_referral = ConceptName.find_by_name("Referral").concept_id

      ob = Observation.joins(:encounter)
        .where(
          encounter: {
            encounter_type: encounter_type,
          },
          obs: {
            concept_id: tx_option,
            value_coded: tx_referral,
            person_id: @patient.patient_id,
          },
        ).where("encounter_datetime BETWEEN ? AND ?", *TimeUtils.day_bounds(@date))
      ob.blank?
    end

    def show_cxca_test?
      return true if new_patient?
      return true if patient_outcome?
      return false unless results_available?
      return false if postponed_treatment?

      encounter_type = EncounterType.find_by name: CXCA_TEST
      return Encounter.joins(:type).where(
               "patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = DATE(?)",
               @patient.patient_id, encounter_type.encounter_type_id, @date
             ).order(encounter_datetime: :desc).blank?
    end

    def new_patient?
      encounter_type = EncounterType.find_by name: "REGISTRATION"

      return Encounter.joins(:type).where(
               "patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = DATE(?)",
               @patient.patient_id, encounter_type.encounter_type_id, @date
             ).first&.observations&.find_by(concept_id: concept("Type of patient").concept_id, value_coded: concept("New patient").concept_id).present?
    end

    def show_cxca_screening_results?
      encounter_type = EncounterType.find_by name: CXCA_SCREENING_RESULTS
      encounter = Encounter.joins(:type).where(
        "patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = DATE(?)",
        @patient.patient_id, encounter_type.encounter_type_id, @date.to_date
      ).order(encounter_datetime: :desc).first

      return false unless encounter.blank?

      unless encounter.blank?
        treatment_option = ConceptName.find_by_name("Directly observed treatment option").concept_id
        referral_concept = ConceptName.find_by_name("Referral").concept_id
        return false if encounter.observations.find_by(concept_id: treatment_option, value_coded: referral_concept).present?

        return encounter.observations.find_by(concept_id: ConceptName.find_by_name("Screening results available").concept_id,
                                              value_coded: ConceptName.find_by_name("Yes").concept_id).blank? ? true : false
      end

      return true
    end

    def show_cancer_treatment?
      return false if postponed_treatment_today?
      return false unless cxca_positive?

      encounter_type = EncounterType.find_by name: CXCA_SCREENING_RESULTS
      encounter = Encounter.joins(:type).where(
        "patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) <= DATE(?)",
        @patient.patient_id, encounter_type.encounter_type_id, @date
      ).order(encounter_datetime: :desc).first

      unless encounter.blank?
        observations = encounter.observations.find_by(concept_id: ConceptName.find_by_name("Screening results available").concept_id)
        return false if observations.value_coded == ConceptName.find_by_name("No").concept_id
      end

      encounter_type = EncounterType.find_by name: CANCER_TREATMENT
      encounter = Encounter.joins(:type).where(
        "patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = DATE(?)",
        @patient.patient_id, encounter_type.encounter_type_id, @date
      ).order(encounter_datetime: :desc).first

      return encounter.blank?
      #return true
    end

    def show_appointment?

=begin
      encounter_type = EncounterType.find_by name: CANCER_TREATMENT
      encounter = Encounter.joins(:type).where(
        'patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) <= DATE(?)',
        @patient.patient_id, encounter_type.encounter_type_id, @date
      ).order(encounter_datetime: :desc).first
=end
      encounter_type = EncounterType.find_by name: APPOINTMENT
      appointment = Encounter.joins(:type).where(
        "patient_id = ? AND encounter_type = ?
        AND DATE(encounter_datetime) = DATE(?) AND program_id = ?",
        @patient.patient_id, encounter_type.encounter_type_id, @date, @program.id
      ).order(encounter_datetime: :desc).first

      encounter_type = EncounterType.find_by name: CANCER_TREATMENT
      cancer_tx = Encounter.joins(:type).where(
        "patient_id = ? AND encounter_type = ?
        AND DATE(encounter_datetime) = DATE(?) AND program_id = ?",
        @patient.patient_id, encounter_type.encounter_type_id, @date, @program.id
      ).order(encounter_datetime: :desc).first

      unless cancer_tx.blank?
        ob = cancer_tx.observations.where(concept_id: concept("Recommended Plan of care").concept_id,
                                          value_coded: concept("Continue follow-up").concept_id)

        if appointment.blank?
          return true unless ob.blank?
        end
      end

      unless appointment.blank?
        return true if negative_screening?
      end

      return appointment.blank?
    end

    def patient_outcome?
      encounter_type = EncounterType.find_by name: CANCER_TREATMENT
      encounter = Encounter.joins(:type).where(
        "patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) <= DATE(?)",
        @patient.patient_id, encounter_type.encounter_type_id, @date
      ).order(encounter_datetime: :desc).first

      return false if encounter.blank?
      result = encounter.observations.where(concept_id: concept("Treatment").concept_id,
                                            value_coded: [
                                              concept("Palliative Care").concept_id,
                                              concept("No Dysplasia/Cancer").concept_id,
                                            ])

      return true unless result.blank?
      return false
    end

    def results_available?
      encounter_type = EncounterType.find_by name: CXCA_SCREENING_RESULTS
      encounter = Encounter.joins(:type).where(
        "patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) <= DATE(?)",
        @patient.patient_id, encounter_type.encounter_type_id, @date
      ).order(encounter_datetime: :desc).first

      unless encounter.blank?
        return encounter.observations.find_by(concept_id: ConceptName.find_by_name("Screening results available").concept_id,
                                              value_coded: ConceptName.find_by_name("No").concept_id).blank? ? true : false
      end

      return true
    end

    def postponed_treatment?
      encounter_type = EncounterType.find_by name: CXCA_SCREENING_RESULTS
      encounter = Encounter.joins(:type).where(
        "patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) <= DATE(?)",
        @patient.patient_id, encounter_type.encounter_type_id, @date
      ).order(encounter_datetime: :desc).first

      unless encounter.blank?
        postponed_tx = ConceptName.find_by_name("Directly observed treatment option").concept_id
        value_coded_concepts = []
        value_coded_concepts << ConceptName.find_by_name("Postponed treatment").concept_id
        value_coded_concepts << ConceptName.find_by_name("Referral").concept_id

        return encounter.observations.find_by(concept_id: postponed_tx,
                                              value_coded: value_coded_concepts).blank? ? false : true
      end

      return false
    end

    def postponed_treatment_today?
      encounter_type = EncounterType.find_by name: CXCA_SCREENING_RESULTS
      encounter = Encounter.joins(:type).where(
        "patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = DATE(?)",
        @patient.patient_id, encounter_type.encounter_type_id, @date
      ).order(encounter_datetime: :desc).first

      unless encounter.blank?
        postponed_tx = ConceptName.find_by_name("Directly observed treatment option").concept_id
        value_coded_concepts = []
        value_coded_concepts << ConceptName.find_by_name("Postponed treatment").concept_id
        value_coded_concepts << ConceptName.find_by_name("Referral").concept_id

        return encounter.observations.find_by(concept_id: postponed_tx,
                                              value_coded: value_coded_concepts).blank? ? false : true
      end

      return false
    end

    def cxca_positive?
      encounter_type = EncounterType.find_by name: CXCA_SCREENING_RESULTS
      encounter = Encounter.joins(:type).where(
        "patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) <= DATE(?)",
        @patient.patient_id, encounter_type.encounter_type_id, @date
      ).order(encounter_datetime: :desc).first

      unless encounter.blank?
        cxca_result_concept_id = concept("Screening results").concept_id
        positive_cxca_results = []
        via_positive = concept("VIA positive").concept_id
        positive_cxca_results << via_positive
        positive_cxca_results << concept("Suspect cancer").concept_id
        positive_cxca_results << concept("PAP Smear Abnormal").concept_id
        hpv_positive = concept("HPV positive").concept_id
        positive_cxca_results << hpv_positive
        positive_cxca_results << concept("Visible Lesion").concept_id

        observation = encounter.observations.where(concept_id: cxca_result_concept_id).order("obs_datetime DESC, obs.date_created DESC").first

        unless observation.blank?
          if observation.value_coded == hpv_positive
            via_concept_ids = ConceptName.where(name: "VIA results").map(&:concept_id)
            via_observation = encounter.observations.where("concept_id IN(?) AND value_coded = ?",
                                                           via_concept_ids, via_positive).order("obs_datetime DESC, obs.date_created DESC").first

            return via_observation.blank? ? false : true
          end
          return positive_cxca_results.include?(observation.value_coded)
        end
      end

      return false
    end

    def offer_cxca_screening?
      encounter_type = EncounterType.find_by name: CXCA_TEST
      encounter = Encounter.joins(:type).where(
        "patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) <= DATE(?)",
        @patient.patient_id, encounter_type.encounter_type_id, @date
      ).order(encounter_datetime: :desc).first

      return false if encounter.blank?
      obs = encounter.observations.where(concept_id: concept("Offer CxCa").concept_id,
                                         value_coded: concept("Yes").concept_id).order("obs_datetime DESC, obs.date_created DESC").first

      return obs.blank? ? false : true
    end

    def negative_screening?
      encounter_type = EncounterType.find_by name: CXCA_SCREENING_RESULTS
      encounter = Encounter.joins(:type).where(
        "patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) <= DATE(?)",
        @patient.patient_id, encounter_type.encounter_type_id, @date
      ).order(encounter_datetime: :desc).first

      result = encounter.observations.where(concept_id: concept("Screening results").concept_id,
                                            value_coded: [
                                              concept("VIA negative").concept_id,
                                              concept("PAP Smear normal").concept_id,
                                              concept("HPV negative").concept_id,
                                              concept("No visible Lesion").concept_id,
                                              concept("Other gynaecological disease").concept_id,
                                            ])

      return true unless result.blank?

      hp_result = encounter.observations.where(concept_id: concept("Screening results").concept_id,
                                               value_coded: concept("HPV positive").concept_id)

      if hp_result
        via_concept_ids = ConceptName.where(name: "VIA results").map(&:concept_id)
        via_negative = encounter.observations.where("concept_id IN(?) AND value_coded = ?",
                                                    via_concept_ids, concept("VIA negative").concept_id)

        return true unless via_negative.blank?
      end

      return false
    end

    def same_day_treatment?
      encounter_type = EncounterType.find_by name: CXCA_SCREENING_RESULTS
      encounter = Encounter.joins(:type).where(
        "patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) <= DATE(?)",
        @patient.patient_id, encounter_type.encounter_type_id, @date
      ).order(encounter_datetime: :desc).first

      unless encounter.blank?
        sameday_tx = ConceptName.find_by_name("Directly observed treatment option").concept_id
        value_coded_concept = ConceptName.find_by_name("Same day treatment").concept_id

        return encounter.observations.find_by(concept_id: sameday_tx,
                                              value_coded: value_coded_concept).blank? ? false : true
      end

      return false
    end

    def concept(name)
      ConceptName.find_by_name(name)
    end
  end
end
