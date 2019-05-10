# frozen_string_literal: true

require 'set'

module TBService
  class WorkflowEngine
    include ModelUtils

    def initialize(program:, patient:, date:)
      @patient = patient
      @program = program
      @date = date
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

        return encounter_type if valid_state?(state)

      end

      nil
    end

    private

    LOGGER = Rails.logger

    # Encounter types TB_INITIAL, TB_FOLLOWUP, TB RECEPTION, TB REGISTRATION
    INITIAL_STATE = 0 # Start terminal for encounters graph
    END_STATE = 1 # End terminal for encounters graph
    TB_INITIAL = 'TB_INITIAL'
    VITALS = 'VITALS'
    LAB_ORDERS = 'LAB ORDERS'
    TREATMENT = 'TREATMENT'
    DISPENSING = 'DISPENSING'
    TB_ADHERENCE = 'TB ADHERENCE'
    DIAGNOSIS = 'DIAGNOSIS'
    LAB_RESULTS =  'LAB RESULTS'
    APPOINTMENT = 'APPOINTMENT'

    #FOLLOW - TB INITIAL, LAB ORDERS. LAB RESULTs, VITALS, TREATMENT, DISPENSING, APPOINTMENT, TB ADHERENCE

    #CONCEPTS
    YES = 1065

    #Ask vitals when TB Positive
    #Diagnosis is for minors under and equal to 5 and suspsets over who are TB on the first encounter negative
    #

    # Encounters graph
    ENCOUNTER_SM = {
      INITIAL_STATE => TB_INITIAL,
      TB_INITIAL => LAB_ORDERS,
      LAB_ORDERS => DIAGNOSIS,
      DIAGNOSIS => LAB_RESULTS,
      LAB_RESULTS => VITALS,
      VITALS => TREATMENT,
      TREATMENT => DISPENSING,
      DISPENSING => APPOINTMENT,
      APPOINTMENT => TB_ADHERENCE,
      TB_ADHERENCE => END_STATE
    }.freeze

    STATE_CONDITIONS = {
      TB_INITIAL => %i[patient_should_go_for_screening?],

      LAB_ORDERS => %i[patient_labs_not_ordered? 
                                    patient_not_tb_negative_through_diagnosis?
                                    patient_should_be_be_tested_through_lab?],
      TB_ADHERENCE => %i[patient_received_tb_drugs?
                                    patient_not_tb_negative_through_diagnosis?
                                    patient_is_not_a_transfer_out?
                                    patient_should_proceed_for_treatment?],
      TREATMENT => %i[patient_should_get_treatment? 
                                    patient_tb_positive?
                                    patient_not_tb_negative_through_diagnosis?
                                    patient_should_proceed_for_treatment?],
      DISPENSING => %i[patient_got_treatment? 
                                    patient_tb_positive?
                                    patient_not_tb_negative_through_diagnosis?
                                    patient_should_proceed_for_treatment?],
      DIAGNOSIS => %i[patient_not_tb_negative_through_diagnosis?
                                    patient_should_be_be_tested_through_diagnosis?],
      LAB_RESULTS => %i[patient_has_no_lab_results?
                                    patient_should_be_be_tested_through_lab?
                                    patient_should_proceed_for_treatment?],
      VITALS => %i[patient_tb_positive?
                                    patient_not_tb_negative_through_diagnosis?
                                    patient_should_proceed_for_treatment?],
      APPOINTMENT => %i[dispensing_complete? 
                                    appointment_not_complete? 
                                    patient_is_not_a_transfer_out?
                                    patient_should_proceed_for_treatment?]
    }.freeze   

    #patient found TB negative under diagnosis should go home

    #/api/v1/programs/:program_id/lab_tests/labs(.:format) 

    # Concepts
    PATIENT_PRESENT = 'Patient present'

    def load_user_activities
      activities = user_property('Activities')&.property_value
      encounters = (activities&.split(',') || []).collect do |activity|
        # Re-map activities to encounters
        puts activity
      case activity
        when /TB initial/i
          TB_INITIAL
        when /TB lab orders/i
          LAB_ORDERS
        when /Vitals/i
          VITALS
        when /Treatment/i
          TREATMENT
        when /Dispensing/i
          DISPENSING
        when /TB Adherence/i
          TB_ADHERENCE 
        when /Diagnosis/i
          DIAGNOSIS 
        when /Lab Results/i
          LAB_RESULTS 
        when /Appointment/i
          APPOINTMENT 
        else
          Rails.logger.warn "Invalid TB activity in user properties: #{activity}"
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
      Encounter.where(type: type, patient: @patient)\
               .where('encounter_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(@date))\
               .exists?
    end

    def valid_state?(state)
      return false if encounter_exists?(encounter_type(state))

      (STATE_CONDITIONS[state] || []).reduce(true) do |status, condition|
        status && method(condition).call
      end
    end
    
    def tb_suspect_not_enrolled?
      Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ? AND DATE(encounter_datetime) = DATE(?)',
        TB_INITIAL,
        @patient.patient_id,
        @date
      ).order(encounter_datetime: :desc).first.nil?
    end

    def patient_labs_not_ordered? #need to avoided to prevent repeating this if result of lab order is not provided
      Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ? AND DATE(encounter_datetime) = DATE(?)',
        LAB_ORDERS,
        @patient.patient_id,
        @date
      ).order(encounter_datetime: :desc).first.nil?
    end

    def patient_should_get_treatment?
      prescribe_drugs_concept = concept('Prescribe drugs')
      yes_concept = concept('Yes')
      start_time, end_time = TimeUtils.day_bounds(@date)
      Observation.where(
        'concept_id = ? AND value_coded = ? AND person_id = ? AND obs_datetime BETWEEN ? AND ?',
        prescribe_drugs_concept.concept_id, yes_concept.concept_id,
        @patient.patient_id, start_time, end_time
      ).order(obs_datetime: :desc).first.present?
    end

    def patient_got_treatment?
      Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ? AND DATE(encounter_datetime) = DATE(?)',
        TREATMENT,
        @patient.patient_id,
        @date
      ).order(encounter_datetime: :desc).first.present?
    end

    def patient_received_tb_drugs?
      drug_ids = Drug.tb_drugs.map(&:drug_id)
      drug_ids_placeholders = "(#{(['?'] * drug_ids.size).join(', ')})"
      Observation.where(
        "person_id = ? AND value_drug in #{drug_ids_placeholders} AND DATE(obs_datetime) <= DATE(?)",
        @patient.patient_id, *drug_ids, @date
      ).order(obs_datetime: :desc).first.present?
    end

    #if minor found TB negative through DIAGONIS, give them ITP
    def patient_is_a_minor? 
     person = Person.find_by(person_id: @patient.patient_id)
     (((Time.zone.now - person.birthdate.to_time) / 1.year.seconds).floor) <= 5
    end

    def patient_not_tb_negative_through_diagnosis?
      encounter = Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ?',
        DIAGNOSIS,
        @patient.patient_id
      ).order(encounter_datetime: :desc).first 

      return true unless encounter #Handle this with an expection

      tb_status = concept('TB status')
      positive = concept('Negative')
      Observation.where(
        "encounter_id = ? AND person_id = ? AND concept_id = ? AND value_coded = ? ",
        encounter.encounter_id, @patient.patient_id, tb_status.concept_id, positive.concept_id
      ).order(obs_datetime: :desc).first.nil?
    end

    def patient_tb_positive? 
      status_concept = concept('TB status')
      negative = concept('Positive')
      Observation.where(
        'person_id = ? AND concept_id = ? AND value_coded = ? AND DATE(obs_datetime) = DATE(?)', #Add Date
        @patient.patient_id, status_concept.concept_id, negative.concept_id, @date
      ).order(obs_datetime: :desc).first.present?
    end

    def patient_tb_negative? 
      status_concept = concept('TB status')
      negative = concept('Negative')
      Observation.where(
        'person_id = ? AND concept_id = ? AND value_coded = ?', 
        @patient.patient_id, status_concept.concept_id, negative.concept_id
      ).order(obs_datetime: :desc).first.present?
    end

    def patient_has_no_lab_results? #LOOK into this
      Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ? AND DATE(encounter_datetime) = DATE(?)',
        LAB_RESULTS,
        @patient.patient_id,
        @date
      ).order(encounter_datetime: :desc).first.nil?
    end

    def dispensing_complete? #Check 
      Encounter.joins(:type).where(
      'encounter_type.name = ? AND encounter.patient_id = ? AND DATE(encounter_datetime) = DATE(?)',
      DISPENSING,
      @patient.patient_id,
      @date
      ).order(encounter_datetime: :desc).first.present?
    end

    def patient_has_no_vitals?
      Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ? AND DATE(encounter_datetime) = DATE(?)',
        VITALS,
        @patient.patient_id, 
        @date
      ).order(encounter_datetime: :desc).first.present? 
    end

    def appointment_not_complete?
      Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ? AND DATE(encounter_datetime) = DATE(?)',
        APPOINTMENT,
        @patient.patient_id, 
        @date
      ).order(encounter_datetime: :desc).first.nil? 
    end

    def patient_has_appointment? 
      Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ? AND DATE(encounter_datetime) < DATE(?)',
        APPOINTMENT,
        @patient.patient_id,
        @date
      ).order(encounter_datetime: :desc).first.present?
    end

    def patient_should_go_for_screening?
      tb_suspect_not_enrolled? || patient_has_appointment? 
    end

    def patient_is_not_a_transfer_out?
      transfer_out = concept 'Transfer out'
      yes_concept = concept 'YES'
      Observation.where(
        "person_id = ? AND concept_id = ? AND value_coded = ? ",
        @patient.patient_id, transfer_out.concept_id, yes_concept.concept_id
      ).order(obs_datetime: :desc).first.nil?
    end
  
    #return to the patient dashboard if patient lab test has been ordered within 1 hour
    def patient_should_proceed_after_lab_order?
      encounter = Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ? AND DATE(encounter_datetime) = DATE(?)',
        LAB_ORDERS,
        @patient.patient_id,
        @date
      ).order(encounter_datetime: :desc).first

      begin
        time_diff = (Time.current - encounter.encounter_datetime)
        hours = (time_diff / 1.hour).round
        (hours >= 1)
      rescue
        false          
      end
    end

    def patient_should_proceed_for_treatment?
      patient_should_proceed_after_lab_order? || patient_tb_positive?
    end

    def patient_should_be_be_tested_through_lab?
      procedure_type = concept 'Procedure type'
      examination_type = concept 'Laboratory examinations'
      Observation.where(
        "person_id = ? AND concept_id = ? AND value_coded = ? AND DATE(obs_datetime) = DATE(?)",
        @patient.patient_id, procedure_type.concept_id, examination_type.concept_id, @date
      ).order(obs_datetime: :desc).first.present?
    end

    def patient_should_be_be_tested_through_diagnosis?
      procedure_type = concept 'Procedure type'
      x_ray = concept 'Xray'
      clinical = concept 'Clinical'
      Observation.where(
        "person_id = ? AND concept_id = ? AND (value_coded = ? || value_coded = ?) AND DATE(obs_datetime) = DATE(?)", #add session date
        @patient.patient_id, procedure_type.concept_id, x_ray.concept_id, clinical.concept_id, @date
      ).order(obs_datetime: :desc).first.present?
    end

  end 
end
