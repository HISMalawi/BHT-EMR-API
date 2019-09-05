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
    LAB_RESULTS = 'LAB RESULTS'
    APPOINTMENT = 'APPOINTMENT'
    TB_REGISTRATION = 'TB REGISTRATION'
    TB_RECEPTION = 'TB RECEPTION'
    REFERRAL = 'REFERRAL'
    # FOLLOW - TB INITIAL, LAB ORDERS. LAB RESULTs, VITALS, TREATMENT, DISPENSING, APPOINTMENT, TB ADHERENCE

    # ART Integration
    ART_WORKFLOW = 'ART WORKFLOW'
    ART_QUESTION = 'ART QUESTION'

    # enable
    ART_INTERGRATION_ENABLED = true

    # CONCEPTS
    YES = 1065

    # Ask vitals when TB Positive
    # Diagnosis is for minors under and equal to 5 and suspsets over who are TB on the first encounter negative
    #

    # Encounters graph
    ENCOUNTER_SM = {
      INITIAL_STATE => TB_INITIAL,
      TB_INITIAL => REFERRAL,
      REFERRAL => LAB_ORDERS,
      LAB_ORDERS => DIAGNOSIS,
      DIAGNOSIS => LAB_RESULTS,
      LAB_RESULTS => TB_RECEPTION,
      TB_RECEPTION => TB_REGISTRATION,
      TB_REGISTRATION => VITALS,
      VITALS => TREATMENT,
      TREATMENT => DISPENSING,
      DISPENSING => APPOINTMENT,
      APPOINTMENT => TB_ADHERENCE,
      TB_ADHERENCE => END_STATE
    }.freeze

    STATE_CONDITIONS = {

      TB_INITIAL => %i[patient_should_go_for_screening?
                                    patient_not_transferred_in_today?
                                    patient_currently_not_on_treatment?],

      REFERRAL => %i[patient_should_go_for_referral?],

      DIAGNOSIS => %i[should_patient_tested_through_diagnosis?
                                    patient_has_no_diagnosis?
                                    patient_not_transferred_in_today?],

      LAB_ORDERS => %i[patient_should_go_for_lab_order?
                                    patient_not_transferred_in_today?],

      LAB_RESULTS => %i[patient_has_no_lab_results?
                                    patient_should_proceed_after_lab_order?
                                    patient_recent_lab_order_has_no_results?
                                    patient_not_transferred_in_today?],

      TB_RECEPTION => %i[patient_has_no_tb_reception?
                                    patient_should_proceed_for_treatment?],

      TB_REGISTRATION => %i[patient_has_no_tb_registration?
                                    patient_is_not_a_transfer_out?
                                    patient_should_proceed_for_treatment?
                                    patient_is_no_a_referral?],

      VITALS => %i[patient_has_no_vitals?
                                    patient_should_proceed_for_treatment?],

      TREATMENT => %i[patient_has_no_treatment?
                                    patient_should_proceed_for_treatment?],

      DISPENSING => %i[patient_got_treatment?
                                    patient_has_no_dispensation?
                                    patient_should_proceed_for_treatment?],

      APPOINTMENT => %i[patient_should_go_for_appointment?],

      TB_ADHERENCE => %i[patient_has_appointment?
                                    patient_has_no_adherence?]

    }.freeze

    # Concepts
    PATIENT_PRESENT = 'Patient present'

    MINOR_AGE_LIMIT = 18

    UNDER_FIVE_AGE_LIMIT = 5

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
        when /TB Registration/i
          TB_REGISTRATION
        when /TB Reception/i
          TB_RECEPTION
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
      # Vitals may be collected from a different program so don't check
      # for existence of an encounter rather check for the existence
      # of the actual vitals.
      return false if type.name == VITALS

      Encounter.where(type: type, patient: @patient, program: @program)\
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
      type = encounter_type('TB_Initial')
      Encounter.where(type: type, patient: @patient, program: @program)\
               .blank?
    end

    def patient_labs_not_ordered?
      Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ? AND encounter.program_id = ?',
        LAB_ORDERS,
        @patient.patient_id,
        @program.program_id
      ).order(encounter_datetime: :desc).first.nil?
    end

    def patient_got_treatment?
      Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ? AND DATE(encounter_datetime) = DATE(?) AND encounter.program_id = ?',
        TREATMENT,
        @patient.patient_id,
        @date,
        @program.program_id
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
    def patient_is_under_five?
     person = Person.find_by(person_id: @patient.patient_id)
     (((Time.zone.now - person.birthdate.to_time) / 1.year.seconds).floor) < UNDER_FIVE_AGE_LIMIT
    end

    def patient_should_get_treated?
      (patient_is_under_five? && patient_current_tb_status_is_negative?) || patient_current_tb_status_is_positive?
    end

    def patient_has_no_lab_results?
      Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ? AND DATE(encounter_datetime) = DATE(?) AND encounter.program_id = ?',
        LAB_RESULTS,
        @patient.patient_id,
        @date,
        @program.program_id
      ).order(encounter_datetime: :desc).first.nil?
    end

    def dispensing_complete? #Check
      Encounter.joins(:type).where(
      'encounter_type.name = ? AND encounter.patient_id = ? AND DATE(encounter_datetime) = DATE(?) AND encounter.program_id = ?',
      DISPENSING,
      @patient.patient_id,
      @date,
      @program.program_id
      ).order(encounter_datetime: :desc).first.present?
    end

    def patient_has_no_vitals?
      return true if patient_has_no_weight_today?

      return true if patient_has_no_height?

      patient_has_no_height_today? && patient_is_a_minor?
    end

    def patient_has_no_weight_today?
      height_concept = concept('Weight')
      Observation.where(concept_id: height_concept.concept_id, person_id: @patient.id)\
                  .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(@date))\
                  .first.nil?
    end

    def patient_has_no_height?
      height_concept = concept('Height (cm)')
      Observation.where(concept_id: height_concept.concept_id, person_id: @patient.id)\
                  .where('obs_datetime < ?', TimeUtils.day_bounds(@date)[1])\
                  .first.nil?
    end

    def patient_has_no_height_today?
      height_concept = concept('Height (cm)')
      Observation.where(concept_id: height_concept.concept_id, person_id: @patient.id)\
                  .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(@date))\
                  .first.nil?
    end

    def patient_is_a_minor?
      @patient.age(today: @date) < MINOR_AGE_LIMIT
    end

    def patient_has_appointment?
      Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ? AND DATE(encounter_datetime) < DATE(?) AND encounter.program_id = ?',
        APPOINTMENT,
        @patient.patient_id,
        @date,
        @program.program_id
      ).order(encounter_datetime: :desc).first.present?
    end

    def patient_is_not_a_transfer_out?
      transfer_out = concept 'Patient transferred(external facility)'
      yes_concept = concept 'YES'
      Observation.where(
        "person_id = ? AND concept_id = ? AND value_coded = ? ",
        @patient.patient_id, transfer_out.concept_id, yes_concept.concept_id
      ).order(obs_datetime: :desc).first.nil?
    end

    #return to the patient dashboard if patient lab test has been ordered within 1 hour
    def patient_should_proceed_after_lab_order?
      encounter = Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ? AND encounter.program_id = ?',
        LAB_ORDERS,
        @patient.patient_id,
        @program.program_id
      ).order(encounter_datetime: :desc).first

      begin
        time_diff = ((Time.now - encounter.encounter_datetime.to_time)).to_i
        (time_diff >= 3)
      rescue
        false
      end

    end

    def patient_recent_lab_order_has_no_results?
      lab_order = Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ? AND encounter.program_id = ?',
        LAB_ORDERS,
        @patient.patient_id,
        @program.program_id
      ).order(encounter_datetime: :desc).first

      lab_result = Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ? AND encounter.program_id = ?',
        LAB_RESULTS,
        @patient.patient_id,
        @program.program_id
      ).order(encounter_datetime: :desc).first

      return true unless lab_result

      begin
        (lab_result.encounter_datetime < lab_order.encounter_datetime)
      rescue
        false
      end

    end

    #patient worklow should proceed after 10 minutes
    def patient_should_proceed_after_diagnosis?
      procedure_type = concept 'Procedure type'
      x_ray = concept 'Xray'
      clinical = concept 'Clinical'
      ultrasound = concept 'Ultrasound'
      observation = Observation.where(
        "person_id = ? AND concept_id = ? AND (value_coded = ? || value_coded = ? || value_coded = ?)",
        @patient.patient_id, procedure_type.concept_id, x_ray.concept_id, clinical.concept_id, ultrasound.concept_id
      ).order(obs_datetime: :desc).first

      begin
        time_diff = (Time.current - observation.obs_datetime)
        minutes = (time_diff / 60)
        (minutes >= 1/60)
      rescue
        false
      end

    end

    # Send the TB patient for a lab order on the 56th/84th/140th/168th day
    def should_patient_go_lab_examination_at_followup?
      first_dispensation = Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ? AND encounter.program_id = ?',
        DISPENSING,
        @patient.patient_id,
        @program.program_id
        ).order(encounter_datetime: :asc).first

      begin
        first_dispensation_date = first_dispensation.encounter_datetime
        number_of_days = (Time.current.to_date - first_dispensation_date.to_date).to_i
        (number_of_days == 56 || number_of_days == 84 || number_of_days == 140 || number_of_days == 168)
      rescue
        false
      end

    end

    def patient_diagnosed?
      patient_should_proceed_after_lab_order? || patient_should_proceed_after_diagnosis?
    end

    def patient_should_go_for_lab_order?
      (should_patient_be_tested_through_lab? && patient_labs_not_ordered?)\
        || (patient_current_tb_status_is_positive? && should_patient_go_lab_examination_at_followup?\
        && patient_recent_lab_order_has_results?)
    end

    def patient_recent_lab_order_has_results?
      lab_order = Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ? AND encounter.program_id = ?',
        LAB_ORDERS,
        @patient.patient_id,
        @program.program_id
      ).order(encounter_datetime: :desc).first

      lab_result = Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ? AND encounter.program_id = ?',
        LAB_RESULTS,
        @patient.patient_id,
        @program.program_id
      ).order(encounter_datetime: :desc).first

      begin
        (lab_result.encounter_datetime > lab_order.encounter_datetime)
      rescue
        false
      end

    end

    def patient_recent_diagonis_has_results?
      procedure_type = concept 'Procedure type'
      x_ray = concept 'Xray'
      clinical = concept 'Clinical'
      ultrasound = concept 'Ultrasound'
      observation = Observation.where(
        "person_id = ? AND concept_id = ? AND (value_coded = ? || value_coded = ? || value_coded = ?)",
        @patient.patient_id, procedure_type.concept_id, x_ray.concept_id, clinical.concept_id, ultrasound.concept_id
      ).order(obs_datetime: :desc).first

      diagnosis = Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ? AND encounter.program_id = ?',
        DIAGNOSIS,
        @patient.patient_id,
        @program.program_id
      ).order(encounter_datetime: :desc).first

      begin
        (diagnosis.encounter_datetime > observation.obs_datetime)
      rescue
        false
      end

    end

    def patient_has_valid_test_results?
      patient_recent_lab_order_has_results? || patient_recent_diagonis_has_results?
    end

    def should_patient_be_tested_through_lab?
      procedure_type = concept 'Procedure type'
      lab_exam = concept 'Laboratory examinations'
      Observation.where(person_id: @patient.patient_id,
                        concept: procedure_type,
                        answer_concept: lab_exam,
                        obs_datetime: @date).exists?
    end

    def should_patient_tested_through_diagnosis?
      procedure_type = concept 'Procedure type'
      clinical = concept 'Clinical'
      Observation.where(person_id: @patient.patient_id,
                        concept: procedure_type,
                        answer_concept: clinical,
                        obs_datetime: @date).exists?
    end

    def patient_has_no_adherence?
      Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ? AND DATE(encounter_datetime) = DATE(?) AND encounter.program_id = ?',
        TB_ADHERENCE,
        @patient.patient_id,
        @date,
        @program.program_id
      ).order(encounter_datetime: :desc).first.nil?
    end

    def patient_has_no_treatment?
      Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ? AND DATE(encounter_datetime) = DATE(?) AND encounter.program_id = ?',
        TREATMENT,
        @patient.patient_id,
        @date,
        @program.program_id
      ).order(encounter_datetime: :desc).first.nil?
    end

    def patient_has_no_dispensation?
      Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ? AND DATE(encounter_datetime) = DATE(?) AND encounter.program_id = ?',
        DISPENSING,
        @patient.patient_id,
        @date,
        @program.program_id
      ).order(encounter_datetime: :desc).first.nil?
    end

    def patient_has_no_appointment?
      Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ? AND DATE(encounter_datetime) = DATE(?) AND encounter.program_id = ?',
        APPOINTMENT,
        @patient.patient_id,
        @date,
        @program.program_id
      ).order(encounter_datetime: :desc).first.nil?
    end

    def patient_has_no_diagnosis?
      Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ? AND DATE(encounter_datetime) = DATE(?) AND encounter.program_id = ?',
        DIAGNOSIS,
        @patient.patient_id,
        @date,
        @program.program_id
      ).order(encounter_datetime: :desc).first.nil?
    end

    def patient_has_lab_results?
      Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ? AND DATE(encounter_datetime) = DATE(?) AND encounter.program_id = ?',
        LAB_RESULTS,
        @patient.patient_id,
        @date,
        @program.program_id
      ).order(encounter_datetime: :desc).first.present?
    end

    def patient_has_tb_results_today?
      status_concept = concept('TB status')
      Observation.where(
        'person_id = ? AND concept_id = ? AND DATE(obs_datetime) = DATE(?)',
        @patient.patient_id, status_concept.concept_id, @date
      ).order(obs_datetime: :desc).first.present?
    end

    def patient_has_adherence?
      Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ? AND DATE(encounter_datetime) = DATE(?) AND encounter.program_id = ?',
        TB_ADHERENCE,
        @patient.patient_id,
        @date,
        @program.program_id
      ).order(encounter_datetime: :desc).first.present?
    end

    def patient_examined?
      patient_has_tb_results_today? || patient_has_adherence?
    end

    def patient_has_no_tb_registration?
      Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ? AND encounter.program_id = ?',
        TB_REGISTRATION,
        @patient.patient_id,
        @program.program_id
      ).order(encounter_datetime: :desc).first.nil?
    end

    def patient_has_no_tb_reception?
      Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ? AND DATE(encounter_datetime) = DATE(?) AND encounter.program_id = ?',
        TB_RECEPTION,
        @patient.patient_id,
        @date,
        @program.program_id
      ).order(encounter_datetime: :desc).first.nil?
    end

    def patient_current_tb_status_is_negative?
      tb_status = concept('TB status')
      negative = concept('Negative')
      status = Observation.where(concept: tb_status,
                                 person_id: @patient.patient_id)\
                          .order(obs_datetime: :desc)

      return true if status.empty?

      status.first.value_coded == negative.concept_id
    end

    def patient_current_tb_status_is_positive?
      status_concept = concept('TB status')
      positive_concept = concept('Positive')
      positive_status = Observation.where(
        'person_id = ? AND concept_id = ?',
        @patient.patient_id, status_concept.concept_id
      ).order(obs_datetime: :desc).first

      begin
        (positive_status.value_coded == positive_concept.concept_id)
      rescue
        false
      end

    end

    def patient_should_go_for_screening?
      (patient_current_tb_status_is_negative? || tb_suspect_not_enrolled?)
    end

    def patient_not_transferred_in_today?
      patient_type = concept('Type of patient')
      referral = concept 'Referral'
      Observation.where(
        'person_id = ? AND concept_id = ? AND value_coded = ? AND DATE(obs_datetime) = DATE(?)',
        @patient.patient_id, patient_type.concept_id, referral.concept_id, @date
      ).order(obs_datetime: :desc).first.nil?
    end

    def patient_transferred_in_today?
      patient_type = concept('Type of patient')
      referral = concept 'Referral'
      Observation.where(
        'person_id = ? AND concept_id = ? AND value_coded = ? AND DATE(obs_datetime) = DATE(?)',
        @patient.patient_id, patient_type.concept_id, referral.concept_id, @date
      ).order(obs_datetime: :desc).first.present?
    end

    def patient_should_proceed_for_treatment?
      (patient_diagnosed? && patient_examined? && patient_should_get_treated?\
        && patient_has_valid_test_results?) || patient_transferred_in_today?
    end

    def load_hiv_program
      Program.find_by(name: 'HIV PROGRAM')
    end

    def patient_on_art_program?
      PatientProgram.find_by(program_id: load_hiv_program.program_id, patient_id: @patient.patient_id).present?
    end

    def patient_is_hiv_positive?
      hiv_status = concept('HIV status')
      positive = concept('Positive')
      Observation.where(
        'person_id = ? AND concept_id = ? AND value_coded = ?',
        @patient.patient_id, hiv_status.concept_id, positive.concept_id
      ).order(obs_datetime: :desc).first.present?
    end

    def patient_art_question_is_available?
      art_need = concept('Antiretroviral treatment needed')
      yes_concept = concept('Yes')
      no_concept = concept('No')
      start_time, end_time = TimeUtils.day_bounds(@date)
      Observation.where(
        'person_id = ? AND concept_id = ? AND (value_coded = ? || value_coded = ?) AND obs_datetime BETWEEN ? AND ?',
        @patient.patient_id, art_need.concept_id, no_concept.concept_id, yes_concept.concept_id, start_time, end_time
      ).order(obs_datetime: :desc).first.nil?
    end

    def patient_should_get_treated_for_art?
      art_need = concept('Antiretroviral treatment needed')
      yes_concept = concept('Yes')
      start_time, end_time = TimeUtils.day_bounds(@date)
      Observation.where(
        'person_id = ? AND concept_id = ? AND value_coded = ? AND obs_datetime BETWEEN ? AND ?',
        @patient.patient_id, art_need.concept_id, yes_concept.concept_id, start_time, end_time
      ).order(obs_datetime: :desc).first.present?
    end

    def patient_has_art_appointment?
      start_time, end_time = TimeUtils.day_bounds(@date)
      Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ? AND encounter.program_id = ? AND encounter.encounter_datetime BETWEEN ? AND ?',
        APPOINTMENT,
        @patient.patient_id,
        load_hiv_program.program_id,
        start_time,
        end_time
      ).order(encounter_datetime: :desc).first.present?
    end

    def patient_has_no_art_appointment?
      start_time, end_time = TimeUtils.day_bounds(@date)
      Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ? AND encounter.program_id = ? AND encounter.encounter_datetime BETWEEN ? AND ?',
        APPOINTMENT,
        @patient.patient_id,
        load_hiv_program.program_id,
        start_time,
        end_time
      ).order(encounter_datetime: :desc).first.nil?
    end

    def patient_has_dispensation?
      start_time, end_time = TimeUtils.day_bounds(@date)
      Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ? AND encounter.program_id = ? AND encounter.encounter_datetime BETWEEN ? AND ?',
        DISPENSING,
        @patient.patient_id,
        @program.program_id,
        start_time,
        end_time
      ).order(encounter_datetime: :desc).first.present?
    end

    def patient_should_go_for_appointment?
      (dispensing_complete? && patient_is_not_a_transfer_out?\
      && patient_has_no_appointment? && patient_should_proceed_for_treatment?)\
      || (patient_has_art_appointment? && patient_has_no_appointment?)
    end

    def patient_should_go_for_referral?
      patient_is_a_referral? && has_no_referral?
    end

    def patient_is_a_referral?
      type_of_patient = concept('Type of patient')
      referral = concept('Referral')
      start_time, end_time = TimeUtils.day_bounds(@date)
      Observation.where(
        'person_id = ? AND concept_id = ? AND value_coded = ? AND obs_datetime BETWEEN ? AND ?',
        @patient.patient_id, type_of_patient.concept_id, referral.concept_id, start_time, end_time
      ).order(obs_datetime: :desc).first.present?
    end

    def patient_is_no_a_referral?
      type_of_patient = concept('Type of patient')
      referral = concept('Referral')
      start_time, end_time = TimeUtils.day_bounds(@date)
      Observation.where(
        'person_id = ? AND concept_id = ? AND value_coded = ? AND obs_datetime BETWEEN ? AND ?',
        @patient.patient_id, type_of_patient.concept_id, referral.concept_id, start_time, end_time
      ).order(obs_datetime: :desc).first.nil?
    end

    def has_no_referral?
      start_time, end_time = TimeUtils.day_bounds(@date)
      Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ? AND encounter.program_id = ? AND encounter.encounter_datetime BETWEEN ? AND ?',
        REFERRAL,
        @patient.patient_id,
        @program.program_id,
        start_time,
        end_time
      ).order(encounter_datetime: :desc).first.nil?
    end

    def patient_currently_not_on_treatment?
      tb_treatment_state = 92
      PatientState.joins(:patient_program)\
                  .where(:patient_program => { patient_id: @patient.patient_id },
                         :patient_state => { state: tb_treatment_state })\
                  .blank?
    end
  end
end
