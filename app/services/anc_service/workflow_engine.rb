module ANCService
  class WorkflowEngine
    include ModelUtils

    HIV_PROGRAM = Program.find_by name: 'HIV PROGRAM'

    def initialize(program:, patient:, date:)
      @patient = patient
      @program = program
      @date = date
      @user_activities = ''
      @activities = load_user_activities
    end

    # Retrieves the next encounter for bound patient
    def next_encounter
      state = INITIAL_STATE
      loop do
        state = next_state state
        break if state == END_STATE

        LOGGER.debug "Loading encounter type: #{state}"
        encounter_type = EncounterType.find_by(name: state)

        if valid_state?(state)
          case encounter_type.name
          when 'TREATMENT'
            return EncounterType.new(name: 'ANC TREATMENT')
          when encounter_type.name == 'DISPENSING'
            return EncounterType.new(name: 'ANC DISPENSING')
          else
            return encounter_type
          end
        end
      end

      nil
    end

    private

    LOGGER = Rails.logger

    # Encounter types
    INITIAL_STATE = 0 # Start terminal for encounters graph
    END_STATE = 1 # End terminal for encounters graph
    VITALS = 'VITALS'.freeze
    DISPENSING = 'DISPENSING'.freeze
    ANC_VISIT_TYPE = 'ANC VISIT TYPE'.freeze
    OBSTETRIC_HISTORY = 'OBSTETRIC HISTORY'.freeze
    MEDICAL_HISTORY = 'MEDICAL HISTORY'.freeze
    SURGICAL_HISTORY = 'SURGICAL HISTORY'.freeze
    SOCIAL_HISTORY = 'SOCIAL HISTORY'.freeze
    LAB_RESULTS = 'LAB RESULTS'.freeze
    CURRENT_PREGNANCY = 'CURRENT PREGNANCY'.freeze # ASSESMENT[sic] - It's how its named in the db
    ANC_EXAMINATION = 'ANC EXAMINATION'.freeze
    APPOINTMENT = 'APPOINTMENT'.freeze
    TREATMENT = 'TREATMENT'.freeze
    HIV_RECEPTION = 'HIV RECEPTION'.freeze
    ART_FOLLOWUP = 'ART_FOLLOWUP'.freeze
    HIV_CLINIC_REGISTRATION = 'HIV CLINIC REGISTRATION'.freeze
    PREGNANCY_STATUS = 'PREGNANCY STATUS'.freeze

    ONE_TIME_ENCOUNTERS = [
      OBSTETRIC_HISTORY, MEDICAL_HISTORY,
      SURGICAL_HISTORY, SOCIAL_HISTORY,
      CURRENT_PREGNANCY
    ].freeze

    # Encounters graph
    ENCOUNTER_SM = {
      INITIAL_STATE => DISPENSING,
      DISPENSING => VITALS,
      VITALS => ANC_VISIT_TYPE,
      ANC_VISIT_TYPE => OBSTETRIC_HISTORY,
      OBSTETRIC_HISTORY => MEDICAL_HISTORY,
      MEDICAL_HISTORY => SURGICAL_HISTORY,
      SURGICAL_HISTORY => SOCIAL_HISTORY,
      SOCIAL_HISTORY => LAB_RESULTS,
      LAB_RESULTS => CURRENT_PREGNANCY,
      CURRENT_PREGNANCY => ANC_EXAMINATION,
      ANC_EXAMINATION => APPOINTMENT,
      APPOINTMENT => TREATMENT,
      TREATMENT => ART_FOLLOWUP,
      ART_FOLLOWUP => HIV_CLINIC_REGISTRATION,
      HIV_CLINIC_REGISTRATION => HIV_RECEPTION,
      HIV_RECEPTION => END_STATE
    }.freeze

    STATE_CONDITIONS = {
      DISPENSING => %i[patient_has_not_been_given_vacination?],
      OBSTETRIC_HISTORY => %i[is_not_a_subsequent_visit?
                              obstetric_history_not_collected?],
      MEDICAL_HISTORY => %i[is_not_a_subsequent_visit?
                            medical_history_not_collected?],
      SURGICAL_HISTORY => %i[is_not_a_subsequent_visit?
                             surgical_history_not_collected?],
      SOCIAL_HISTORY => %i[is_not_a_subsequent_visit?
                           social_history_not_collected?],
      CURRENT_PREGNANCY => %i[is_not_a_subsequent_visit?
                              current_pregnancy_not_collected?],
      ART_FOLLOWUP => %i[patient_is_hiv_positive?],
      HIV_CLINIC_REGISTRATION => %i[patient_is_hiv_positive?
                                    proceed_to_pmtct?
                                    patient_is_not_enrolled_in_art?],
      HIV_RECEPTION => %i[patient_is_hiv_positive?
                          proceed_to_pmtct?]

    }.freeze

    def load_user_activities
      activities = user_property('Activities')&.property_value
      encounters = (activities&.split(',') || []).collect do |activity|
        # Re-map activities to encounters
        # puts activity
        case activity
        when /vitals/i
          VITALS
        when /TD Vaccination/i
          DISPENSING
        when /anc visit type/i
          ANC_VISIT_TYPE
        when /obstetric history/i
          OBSTETRIC_HISTORY
        when /medical history/i
          MEDICAL_HISTORY
        when /surgical history/i
          SURGICAL_HISTORY
        when /social history/i
          SOCIAL_HISTORY
        when /lab results/i
          LAB_RESULTS
        when /current pregnancy/i
          CURRENT_PREGNANCY
        when /ANC examination/i
          ANC_EXAMINATION
        when /ARV Follow Up/i
          ART_FOLLOWUP
        when /hiv clinic registration/i
          HIV_CLINIC_REGISTRATION
        when /hiv reception visits/i
          HIV_RECEPTION
        when /manage appointment/i
          APPOINTMENT
        when /give drugs/i
          TREATMENT
        else
          Rails.logger.warn "Invalid ANC activity in user properties: #{activity}"
        end
      end

      Set.new(encounters)
    end

    def next_state(current_state)
      ENCOUNTER_SM[current_state]
    end

    # Check if a relevant encounter of given type exists for given patient.
    #
    # NOTE: By `relevant` above we mean encounters that matter in deciding
    # what encounter the patient should go for in this present time.
    def encounter_exists?(type)
      if type == encounter_type('TREATMENT')
        return patient_not_receiving_treatment_today? || patient_has_been_given_drugs?
      end

      Encounter.where(type: type, patient: @patient)\
               .where('encounter_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(@date))\
               .exists?
    end

    def valid_state?(state)
      return false unless @activities.include?(state)

      if (is_not_a_subsequent_visit? || !ONE_TIME_ENCOUNTERS.include?(state)) && encounter_exists?(encounter_type(state))
        return false
      end

      (STATE_CONDITIONS[state] || []).reduce(true) do |status, condition|
        status && method(condition).call
      end
    end

    # Check if patient is not been given vacination
    def patient_has_not_been_given_vacination?
      td_drug = Drug.find_by name: 'TD (0.5ml)'
      Encounter.joins(orders: [:drug_order])
               .where("encounter.patient_id = ? AND drug_order.drug_inventory_id = ?
                      AND DATE(encounter.encounter_datetime) = DATE(?) AND program_id = ?",
                      @patient.patient_id, td_drug.id, @date, @program.id)
               .order(encounter_datetime: :desc).first.blank?
    end

    def patient_not_receiving_treatment_today?
      med_recv_concept = ConceptName.find_by_name('Medication received at vist').concept_id
      no_concept = ConceptName.find_by_name('No').concept_id
      treatment_enc = EncounterType.find_by name: TREATMENT
      obs = Encounter.joins([:observations])
                     .where("encounter.patient_id = ? AND encounter.encounter_type = ?
                            AND obs.concept_id = ? AND obs.value_coded = ?
                            AND DATE(encounter.encounter_datetime) = DATE(?)",
                            @patient.patient_id, treatment_enc.id, med_recv_concept, no_concept, @date)
      !obs.blank?
    end

    def patient_has_been_given_drugs?
      td_drug = Drug.find_by name: 'TD (0.5ml)'
      drugs = []

      ActiveRecord::Base.connection.select_all(
        "SELECT drug_order.drug_inventory_id FROM encounter INNER JOIN orders
          ON orders.encounter_id = encounter.encounter_id
          AND orders.voided = 0
        INNER JOIN drug_order ON drug_order.order_id = orders.order_id
        WHERE encounter.voided = 0 AND encounter.program_id = #{@program.id}
        AND (encounter.patient_id = #{@patient.patient_id}
          AND DATE(encounter.encounter_datetime) = DATE('#{@date}'))
          ORDER BY encounter.encounter_datetime DESC"
      ).rows.collect { |d| drugs << d[0] }.compact

      drugs.delete(td_drug.id)

      !drugs.empty?
    end

    def patient_is_hiv_positive?
      current_status = ConceptName.find_by name: 'HIV Status'
      prev_test_done = Observation.where(person: @patient.person, concept: concept('Previous HIV Test Done'))
                                  .order(obs_datetime: :desc)
                                  .first&.value_coded
      date_of_last_mp = date_of_lnmp
      lmp = date_of_last_mp.blank? ? (@date - 45.week) : date_of_last_mp
      if prev_test_done == 1065 # if value is Yes, check prev hiv status
        prev_hiv_test_res = Observation.where(['person_id = ? and concept_id = ? and obs_datetime > ?',
                                               @patient.person.id, ConceptName.find_by_name('Previous HIV Test Results').concept_id, lmp])
                                       .order(obs_datetime: :desc)
                                       .first&.value_coded
        prev_status = ConceptName.find_by_concept_id(prev_hiv_test_res)&.name
        return true if prev_status&.to_s&.downcase == 'positive'
      end

      hiv_test_res = Observation.where(['person_id = ? and concept_id = ? and obs_datetime > ?',
                                        @patient.person.id, current_status.concept_id, lmp])
                                .order(obs_datetime: :desc)
                                .first&.value_coded # rescue nil

      hiv_status = hiv_test_res.blank? ? nil : ConceptName.find_by_concept_id(hiv_test_res).name

      hiv_status ||= prev_status
      hiv_status&.downcase == 'positive'
    end

    def patient_is_not_enrolled_in_art?
      PatientProgram.where('program_id = ? AND patient_id = ?', HIV_PROGRAM.id, @patient.id).blank?
    end

    # Check if surgical history has been collected

    def surgical_history_not_collected?
      lmp_date = date_of_lnmp
      return true if lmp_date.nil?

      surgical_history_enc = EncounterType.find_by name: SURGICAL_HISTORY
      Encounter.where('encounter_type = ? AND patient_id = ? AND DATE(encounter_datetime) >= DATE(?)',
                      surgical_history_enc.id, @patient.patient_id, lmp_date)
               .blank?
    end

    # Checks if this is the subsequent visit
    #
    def is_not_a_subsequent_visit?
      lmp_date = date_of_lnmp
      return true if lmp_date.nil?

      visit_type = EncounterType.find_by name: ANC_VISIT_TYPE
      reason_for_visit = ConceptName.find_by name: 'Reason for visit'

      Encounter.joins(:observations)
               .where("encounter.encounter_type = ? AND concept_id = ? AND encounter.patient_id = ? AND
                      DATE(encounter.encounter_datetime) >= DATE(?)", visit_type.id, reason_for_visit.concept_id,
                      @patient.patient_id, lmp_date)
               .order(encounter_datetime: :desc).first.blank?
    end

    def obstetric_history_not_collected?
      lmp_date = date_of_lnmp
      return true if lmp_date.nil?

      obstetric_encounter = EncounterType.find_by name: OBSTETRIC_HISTORY

      Encounter.where('encounter_type = ? AND patient_id = ? AND DATE(encounter_datetime) >= DATE(?)',
                      obstetric_encounter.id, @patient.patient_id, lmp_date)
               .order(encounter_datetime: :desc).first.blank?
    end

    def medical_history_not_collected?
      lmp_date = date_of_lnmp
      return true if lmp_date.nil?

      medical_history_enc = EncounterType.find_by name: MEDICAL_HISTORY

      Encounter.where('encounter_type = ? AND patient_id = ? AND DATE(encounter_datetime) >= DATE(?)',
                      medical_history_enc.id, @patient.patient_id, lmp_date)
               .order(encounter_datetime: :desc).first.blank?
    end

    def social_history_not_collected?
      lmp_date = date_of_lnmp
      return true if lmp_date.nil?

      social_history_enc = EncounterType.find_by name: SOCIAL_HISTORY

      Encounter.where('encounter_type = ? AND patient_id = ? AND DATE(encounter_datetime) >= DATE(?)',
                      social_history_enc.id, @patient.patient_id, lmp_date)
               .order(encounter_datetime: :desc).first.blank?
    end

    def current_pregnancy_not_collected?
      lmp_date = date_of_lnmp
      return true if lmp_date.nil?

      curr_preg_enc = EncounterType.find_by name: CURRENT_PREGNANCY

      Encounter.where('encounter_type = ? AND patient_id = ? AND DATE(encounter_datetime) >= DATE(?)',
                      curr_preg_enc.id, @patient.patient_id, lmp_date)
               .order(encounter_datetime: :desc).first.blank?
    end

    def proceed_to_pmtct?
      art_followup = EncounterType.find_by name: ART_FOLLOWUP
      pmtct = ConceptName.find_by name: 'PMTCT'
      yes   = ConceptName.find_by name: 'Yes'

      proceed = Encounter.joins([:observations])
                         .where("encounter_type = ? AND obs.concept_id = ? AND patient_id = ?
                                AND (value_coded = ? OR value_text = 'Yes')", art_followup.id,
                                pmtct.concept_id, @patient.patient_id, yes.concept_id)
                         .order(encounter_datetime: :desc).first.blank?

      !proceed
    end

    def date_of_lnmp
      ANCService::PregnancyService.date_of_lnmp(@patient, @date)
    end
  end
end
