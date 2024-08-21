# frozen_string_literal: true

require 'set'
require 'date'

module TbService
  class WorkflowEngine
    include ModelUtils

    def initialize(program:, patient:, date:, workflow_params: {})
      @workflow_params = workflow_params
      @patient = patient
      @program = program
      @date = date
      @starting_from_date = reference_date
      @activities = load_user_activities
    end

    GLOBAL_GUARD_CONDITIONS = %i[transferred_out?]

    def guard?
      GLOBAL_GUARD_CONDITIONS.reduce(false) { |acc, condition| (acc || method(condition).call) }
    end

    def next_encounter
      return nil if guard?
      ENCOUNTERS_SM.each do |state|
        LOGGER.debug "Loading encounter type: #{state}"
        encounter_type = EncounterType.find_by(name: state)
        return encounter_type if valid_state?(state)
      end
      nil
    end

    private

    LOGGER = Rails.logger

    TB_INITIAL = 'TB_INITIAL'
    REGIMEN_INITIAL = 'REGIMEN INITIAL'
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
    EXAMINATION = 'EXAMINATION'
    COMPLICATIONS = 'COMPLICATIONS'
    UPDATE_PREGNANCY_STATUS = 'UPDATE PREGNANCY STATUS'
    UPDATE_HIV_STATUS = 'UPDATE HIV STATUS'

    ENCOUNTERS_SM = [
      TB_INITIAL,
      UPDATE_PREGNANCY_STATUS,
      UPDATE_HIV_STATUS,
      EXAMINATION,
      REFERRAL,
      LAB_ORDERS,
      DIAGNOSIS,
      LAB_RESULTS,
      TB_RECEPTION,
      VITALS,
      TB_ADHERENCE,
      COMPLICATIONS,
      TB_REGISTRATION,
      REGIMEN_INITIAL,
      TREATMENT,
      DISPENSING,
      APPOINTMENT
    ]

    # CONCEPTS
    YES = 1065

    STATE_CONDITIONS = {
      TB_INITIAL => %i[patient_not_transferred_in_today?
                      tb_suspect_not_enrolled?],

      UPDATE_PREGNANCY_STATUS => %i[should_go_for_pregnancy_check?],

      UPDATE_HIV_STATUS => %i[should_go_for_hiv_check?],

      EXAMINATION => %i[go_to_examination?],

      REFERRAL => %i[patient_should_go_for_referral?],

      DIAGNOSIS => %i[patient_should_go_for_diagnosis?],

      LAB_ORDERS => %i[patient_should_go_for_lab_order?
                       patient_not_transferred_in_today?],

      LAB_RESULTS => %i[patient_should_go_for_lab_results? patient_not_transferred_in_today?],

      TB_RECEPTION => %i[no_tb_reception? patient_should_proceed_for_treatment?],

      TB_REGISTRATION => %i[patient_needs_registration_number?
                            patient_should_proceed_for_treatment?
                            patient_is_no_a_referral?],

      VITALS => %i[no_vitals_today? patient_should_proceed_for_treatment?],

      REGIMEN_INITIAL => %i[mdr_regimen_state_has_changed?],

      TREATMENT => %i[patient_has_no_treatment? patient_should_proceed_for_treatment?],

      DISPENSING => %i[got_treatment? patient_has_no_dispensation?],

      APPOINTMENT => %i[patient_should_go_for_appointment?],

      TB_ADHERENCE => %i[patient_has_appointment? patient_has_no_adherence? applicable_time_to_check_adherence?],

      COMPLICATIONS => %i[patient_has_adherence? patient_has_no_complications?]

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
        when /Initial Visit/i
          TB_INITIAL
        when /Examination/i
          EXAMINATION
        when /Lab Orders/i
          LAB_ORDERS
        when /Vitals/i
          VITALS
        when /Update Pregnancy Status/i
          UPDATE_PREGNANCY_STATUS
        when /Regimen Initial/i
          REGIMEN_INITIAL
        when /Treatment/i
          TREATMENT
        when /Dispensing/i
          DISPENSING
        when /Adherence/i
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
        when /Side Effects/i
          COMPLICATIONS
        else
          Rails.logger.warn "Invalid TB activity in user properties: #{activity}"
        end
      end

      # logger = Rails.logger
      # logger.info "#{encounters}"
      Set.new(encounters)
    end

    def reference_date
      service = PatientService.new
      service.patient_last_outcome_date @patient.patient_id, @program.program_id, @date
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
      return false if (encounter_exists?(encounter_type(state)) && !@activities.include?(state)) ||
          (@workflow_params.key?('ignore_encounters') && @workflow_params['ignore_encounters'].include?(state))

      (STATE_CONDITIONS[state] || []).reduce(true) do |status, condition|
        status && method(condition).call
      end
    end

    def mdr_service
      TbService::TbMdrService.new(@patient.patient_id, @program.program_id, @date)
    end

    def mdr_patient?
      mdr_service.patient_on_mdr_treatment?
    end

    def mdr_regimen_state_has_changed?
      regimen = mdr_service.get_regimen_status
      if regimen[:mdr_status]
          (!regimen.has_key?(:regimen_title)) || (!regimen[:issues].blank?) ||
          (regimen[:end_of_phase] && !regimen[:next_phase].nil?) ||
          (!patient_has_tb_results_today? && regimen[:overdue_examination])
      end
    end

    def tb_suspect_enrolled?
      tb_initial_ref.present?
    end

    def tb_suspect_not_enrolled?
      tb_initial_ref.blank?
    end

    def patient_labs_not_ordered?
      last_lab_order.blank?
    end

    def got_treatment?
      start_time, end_time = TimeUtils.day_bounds(@date)
      treatment_ref.where(obs_datetime: start_time..end_time).present?
    end

    # if minor found TB negative through DIAGONIS, give them TPT
    def patient_is_under_five?
      person = Person.find_by(person_id: @patient.patient_id)
      ((Time.zone.now - person.birthdate.to_time) / 1.year.seconds).floor < UNDER_FIVE_AGE_LIMIT
    end

    def patient_should_get_treated?
      (patient_is_under_five? && patient_current_tb_status_is_negative?)\
      || (currently_on_treatment? && patient_current_tb_status_is_negative?)\
      || patient_current_tb_status_is_positive?
    end

    MDR_STATE = 174
    TB_STATE = 92
    def currently_on_treatment?
      PatientState.joins(:patient_program)\
                  .where(patient_program: { program_id: @program, patient_id: @patient },
                         patient_state: { state: [MDR_STATE, TB_STATE], end_date: nil })\
                  .exists?
    end

    def last_lab_result
      lab_result_ref.order(obs_datetime: :desc).first
    end

    def patient_has_no_lab_results?
      lab_result_ref.blank?
    end

    def patient_has_lab_results?
      last_lab_result.present?
    end

    def no_vitals_today?
      vitals = encounter_type('Vitals')
      start_time, end_time = TimeUtils.day_bounds(@date)
      Encounter.where(program: @program,
                      patient: @patient,
                      type: vitals,
                      encounter_datetime: start_time..end_time)\
               .blank?
    end

    def applicable_time_to_check_adherence?
      begin
        appointment_given_date = Date.parse(appointment_ref.order(obs_datetime: :desc).first.obs_datetime.strftime('%F'))
        duration = (Date.parse(@date.to_s) - appointment_given_date).to_i
        duration >= 1
      rescue StandardError
        false
      end
    end

    def patient_has_appointment?
      appointment_ref.order(obs_datetime: :desc).present?
    end

    def patient_has_no_appointment?
      start_time, end_time = TimeUtils.day_bounds(@date)
      appointment_ref.where(obs_datetime: start_time..end_time).blank?
    end

    def patient_should_go_for_appointment?
      (patient_has_dispensation? && patient_is_not_a_transfer_out? && patient_has_no_appointment? && patient_should_proceed_for_treatment?)
    end

    def patient_is_not_a_transfer_out?
      tb_initial_ref('Patient transferred(external facility)')\
              .where(value_coded: concept('YES').concept_id)\
              .order(obs_datetime: :desc).first
              .blank?
    end

    TRANSFERRED_OUT_STATE = 95
    def transferred_out?
      PatientState.joins(:patient_program)\
                  .where(patient_program: { program_id: @program, patient_id: @patient },
                         patient_state: { state: TRANSFERRED_OUT_STATE, end_date: nil })\
                  .exists?
    end

    def patient_recent_lab_order_has_no_results?
      begin
        (last_lab_order.obs_datetime > last_lab_result.obs_datetime)
      rescue StandardError
        return last_lab_order.present?
      end
    end

    # patient worklow should proceed after 10 minutes
    def patient_should_proceed_after_diagnosis?
      observation = patient_recent_diagnosis
      begin
        time_diff = (Time.current - observation.obs_datetime)
        minutes = (time_diff / 60)
        (minutes >= 1 / 60)
      rescue StandardError
        false
      end
    end

    # Send the TB patient for a lab order on the 56th/84th/140th/168th day
    def should_patient_go_lab_examination_at_followup?
      first_dispensation = dispensation_ref.order(obs_datetime: :asc).first
      begin
        last_order = get_last_lab_order_duration
        current_date = Date.parse(@date.to_s)
        first_dispensation_date = Date.parse(first_dispensation.obs_datetime.strftime('%F'))

        number_of_days = (current_date - first_dispensation_date).to_i

        (number_of_days >= 56 && number_of_days <= 84 && (last_order.nil? || last_order >= (84 - 54)))\
        || (number_of_days >= 84 && number_of_days <= 140 && (last_order.nil? || last_order >= (140 - 84)))\
        || (number_of_days >= 140 && number_of_days <= 168 && (last_order.nil? || last_order >= (168 - 140)))
      rescue StandardError
        false
      end
    end

    def get_last_lab_order_duration
      begin
        current_date = Date.parse(@date.to_s)
        order_date = Date.parse(last_lab_order.obs_datetime.strftime('%F'))
        (current_date - order_date).to_i
      rescue StandardError
        nil
      end
    end

    def patient_diagnosed?
      patient_should_proceed_after_diagnosis?
    end

    def patient_should_go_for_lab_order?
      (patient_labs_not_ordered? && should_patient_be_tested_through_lab?)\
      || (resend_patient_for_lab_order? && should_patient_be_tested_through_lab? && patient_current_tb_status_is_negative?)\
      || (should_patient_be_tested_through_lab? && patient_current_tb_status_is_positive? && should_patient_go_lab_examination_at_followup? && !mdr_patient?)
    end

    def patient_recent_lab_order_has_results?
      begin
        logger = Rails.logger
        logger.info "PATIENT RECENT LAB ORDER HAS RESULTS:::::::::: #{(last_lab_result.obs_datetime > last_lab_order.obs_datetime)}"
        (last_lab_result.obs_datetime > last_lab_order.obs_datetime)
      rescue StandardError
        false
      end
    end

    def patient_recent_diagonis_has_results?
      begin
        (patient_recent_diagnosis_result.obs_datetime >= patient_recent_diagnosis.obs_datetime)
      rescue StandardError
        false
      end
    end

    def patient_recent_diagonis_has_no_results?
     !patient_recent_diagonis_has_results?
    end

    def patient_has_valid_test_results?
      patient_recent_lab_order_has_results? || patient_recent_diagonis_has_results?
    end

    def should_patient_be_tested_through_lab?
      examination = examination_ref.order(obs_datetime: :desc).first
      examination.value_coded == concept('Laboratory examinations').concept_id if examination.present?
    end

    def should_patient_tested_through_diagnosis?
      examination = examination_ref.order(obs_datetime: :desc).first
      examination.value_coded == concept('Clinical').concept_id if examination.present?
    end

    def patient_has_adherence?
      adhrence_ref.order(obs_datetime: :desc).first.present?
    end

    def patient_has_no_adherence?
      start_time, end_time = TimeUtils.day_bounds(@date)
      adhrence_ref.where(obs_datetime: start_time..end_time).order(obs_datetime: :desc).first.blank?
    end

    def patient_has_no_treatment?
      start_time, end_time = TimeUtils.day_bounds(@date)
      treatment_ref.where(obs_datetime: start_time..end_time).blank?
    end

    def patient_has_dispensation?
      start_time, end_time = TimeUtils.day_bounds(@date)
      dispensation_ref.where(obs_datetime: start_time..end_time).present?
    end

    def patient_has_no_dispensation?
      start_time, end_time = TimeUtils.day_bounds(@date)
      dispensation_ref.where(obs_datetime: start_time..end_time).blank?
    end

    def patient_has_no_diagnosis?
      patient_recent_diagnosis.blank?
    end

    def patient_has_tb_results_today?
      start_time, end_time = TimeUtils.day_bounds(@date)
      tb_status_ref.where(obs_datetime: start_time..end_time).order(obs_datetime: :desc).present?
    end

    def patient_needs_registration_number?
      mdr_patient? ? patient_has_no_mdr_registration? : patient_has_no_tb_registration?
    end

    def patient_has_no_mdr_registration?
      tb_registration_ref('TB MDR registration number').order(obs_datetime: :desc).first.blank?
    end

    def patient_has_no_tb_registration?
      tb_registration_ref.order(obs_datetime: :desc).order(obs_datetime: :desc).first.blank?
    end

    def no_tb_reception?
      start_time, end_time = TimeUtils.day_bounds(@date)
      tb_reception_ref.where(obs_datetime: start_time..end_time).blank?
    end

    def patient_current_tb_status_is_negative?
      (last_tb_status.value_coded == concept('Negative').concept_id)
    rescue StandardError
      false
    end

    def patient_current_tb_status_is_positive?
      (last_tb_status.value_coded == concept('Positive').concept_id)
    rescue StandardError
      false
    end

    def no_examination_seleted?
      examination_ref.blank?
    end

    def go_to_examination?
      rescreen_patient? || (patient_not_transferred_in_today? && no_examination_seleted?\
      && tb_suspect_enrolled?)
    end

    def mdr_transfer_in_today?
      obs = tb_initial_ref.where(concept: concept('Type of patient'))
                          .where('DATE(obs_datetime) = DATE(?)', @date)
                          .order(obs_datetime: :desc)
                          .first
      obs.value_coded === concept('Transfer in MDR-TB patient').concept_id if obs.present?
    end

    def patient_transferred_in_today?
      tb_initial_ref.where(value_coded: concept('Referral').concept_id)
                    .where('DATE(obs_datetime) = DATE(?)', @date)
                    .order(obs_datetime: :desc)
                    .first
                    .present?
    end

    def patient_not_transferred_in_today?
      !mdr_transfer_in_today? && !patient_transferred_in_today?
    end

    def patient_should_proceed_for_treatment?
      # We do not want to block treatment when Expected lab result will
      # take longer(Has a turnaround period), especially if the patient is on treatment
      (currently_on_treatment? && patient_recent_lab_order_has_no_results? && !recent_order_turnaround_period_complete?)\
      || (patient_diagnosed? && patient_should_get_treated? && patient_has_valid_test_results?)\
      ||  patient_transferred_in_today? || (patient_should_get_treated? && patient_has_valid_test_results?) || mdr_transfer_in_today?
    end

    def patient_should_go_for_referral?
      patient_is_a_referral? && has_no_referral?
    end

    def patient_is_a_referral?
      tb_initial_ref.where(value_coded: concept('Referral').concept_id)
                    .order(obs_datetime: :desc)\
                    .first
                    .present?
    end

    def patient_is_no_a_referral?
      !patient_is_a_referral?
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

    def rescreen_patient?
      begin
        (patient_has_current_tb_results? && patient_current_tb_status_is_negative? && !currently_on_treatment?)\
        && !patient_is_under_five?
      rescue StandardError
        false
      end
    end

    def rediagnose_patient?
      patient_screened_with_no_results? && patient_current_tb_status_is_negative?
    end

    def resend_patient_for_lab_order?
      begin
        last_examination.obs_datetime > last_lab_order.obs_datetime
      rescue StandardError
        false
      end
    end

    def patient_has_current_tb_results?
      begin
        (last_tb_status.obs_datetime > last_examination.obs_datetime)
      rescue StandardError
        false
      end
    end

    def patient_screened_with_no_results?
      begin
        (last_examination.obs_datetime > last_tb_status.obs_datetime)
      rescue StandardError
        false
      end
    end

    def last_examination
      examination_ref.order(obs_datetime: :desc).first
    end

    def last_tb_status
      tb_status_ref.order(obs_datetime: :desc).first
    end

    def patient_should_go_for_diagnosis?
      (patient_has_no_diagnosis? && patient_not_transferred_in_today? && should_patient_tested_through_diagnosis?)\
      || (rediagnose_patient? && alternate_test_procedure_type)
    end

    def resend_patient_diagnosis?
      begin
        patient_recent_diagnosis.obs_datetime > last_selected_lab_examination_procedure.obs_datetime
      rescue StandardError
        false
      end
    end

    # patient should get diagnised through lab order
    def alternate_test_procedure_type
      begin
        patient_recent_diagnosis.obs_datetime > last_lab_order.obs_datetime
      rescue StandardError
        return true if last_lab_order.nil?
      end
    end

    def recent_order_turnaround_period_complete?
      lab_order_ref('Estimated turnaround time for result')\
                .where('value_datetime > ?', @date)\
                .order(obs_datetime: :desc)
                .blank?
    end

    def patient_should_go_for_lab_results?
      (patient_recent_lab_order_has_no_results? && recent_order_turnaround_period_complete?) || rediagnose_patient?
    end

    def patient_has_no_complications?
      start_time, end_time = TimeUtils.day_bounds(@date)
      complications_ref.where(obs_datetime: start_time..end_time)
                      .order(obs_datetime: :desc).first
                      .blank?
    end

    def should_go_for_pregnancy_check?
      if is_female? && in_fertility_age_range? && !pregnant?
        return pregnancy_check_overdue? || no_pregnancy_status?
      end
      false
    end

    def should_go_for_hiv_check?
      negative = not_hiv?
      negative && hiv_check_overdue? || negative.nil?
    end

    def not_hiv?
      obs = hiv_ref.order(obs_datetime: :desc).first
      obs.value_coded === concept('Negative').concept_id if obs.present?
    end

    def hiv_check_overdue?
      obs = hiv_ref.order(obs_datetime: :desc).first
      if obs.present?
        status_date = Date.parse(obs.obs_datetime.strftime("%F"))
        duration = (Date.parse(@date.to_s)-status_date).to_i
        return duration >= 28
      end
      false
    end

    def is_female?
      person = Person.find_by(person_id: @patient.patient_id)
      person.gender == 'F'
    end

    def in_fertility_age_range?
      person = Person.find_by(person_id: @patient.patient_id)
      (9..55).include? ((Time.zone.now - person.birthdate.to_time) / 1.year.seconds).floor
    end

    def pregnancy_check_overdue?
      obs = pregnancy_ref.order(obs_datetime: :desc).first
      if obs.present?
        status_date = Date.parse(obs.obs_datetime.strftime("%F"))
        duration = (Date.parse(@date.to_s)-status_date).to_i
        return duration >= 28
      end
      false
    end

    def no_pregnancy_status?
        pregnancy_ref.blank?
    end

    def pregnant?
      obs = pregnancy_ref.order(obs_datetime: :desc).first
      obs.present? ? obs.value_coded == concept('Yes').concept_id : false
    end

    def last_selected_lab_examination_procedure
      examination_ref.where(value_coded: concept('Laboratory examinations').concept_id)\
                            .order(obs_datetime: :desc)
                            .first
    end

    def last_selected_clinical_examination_procedure
      examination_ref.where(value_coded: concept('Clinical').concept_id)\
                            .order(obs_datetime: :desc)
                            .first
    end

    def last_lab_order
     lab_order_ref.where(value_coded: concept('Tuberculous').concept_id)\
                  .order(obs_datetime: :desc)
                  .first
    end

    def patient_recent_diagnosis
      procedures = [
        concept('Xray').concept_id,
        concept('Clinical').concept_id,
        concept('Ultrasound').concept_id
      ]
      diagnosis_ref.where(value_coded: procedures)\
                  .order(obs_datetime: :desc)\
                  .first
    end

    def patient_recent_diagnosis_result
     diagnosis_ref('Clinically Diagnosed')\
             .where(value_coded: concept('Yes').concept_id)\
             .order(obs_datetime: :desc)\
             .first
    end

    def tb_status_ref(name = "TB status")
      get_obs_without_encounter(name)
    end

    def treatment_ref(name = "Medication orders")
      get_obs(TREATMENT, name)
    end

    def tb_registration_ref(name = 'TB registration number')
      get_obs(TB_REGISTRATION, name)
    end

    def tb_reception_ref(name = 'Patient lives or works near?')
      get_obs(TB_RECEPTION, name)
    end

    def tb_initial_ref(name = 'Type of patient')
      get_obs(TB_INITIAL, name)
    end

    def complications_ref(name = 'MLW TB side effects')
      get_obs(COMPLICATIONS, name)
    end

    def appointment_ref(name = 'Appointment date')
      get_obs(APPOINTMENT, name)
    end

    def lab_order_ref(name = 'Test type')
      get_obs(LAB_ORDERS, name)
    end

    def lab_result_ref(name = 'TB status')
      get_obs(LAB_RESULTS, name)
    end

    def diagnosis_ref(name = 'Procedure type')
      get_obs(DIAGNOSIS, name)
    end

    def adhrence_ref(name = 'Amount of drug brought to clinic')
      get_obs(TB_ADHERENCE, name)
    end

    def pregnancy_ref
      get_obs_without_encounter('Patient pregnant')
    end

    def examination_ref(name = 'Procedure type')
      get_obs(EXAMINATION, name)
    end

    def dispensation_ref(name = 'Amount dispensed')
      get_obs(DISPENSING, name)
    end

    def hiv_ref(name = '')
      get_obs_without_encounter('HIV status', false)
    end

    def get_obs(encounter_name, concept_name, filter_by_outcome_date = true)
      query_set = Observation.joins(:encounter)
                             .where(encounter: {
                                    type: encounter_type(encounter_name),
                                    patient: @patient,
                                    program: @program})
                            .where(concept: concept(concept_name))
                            .where('DATE(obs_datetime) <= DATE(?)', @date)
      query_set = query_set.where('obs_datetime >= ?', @starting_from_date) if filter_by_outcome_date
      return query_set
    end

    def get_obs_without_encounter(concept_name, filter_by_outcome_date = true)
      query_set = Observation.where(person_id: @patient.patient_id)
                             .where(concept: concept(concept_name))
                             .where('DATE(obs_datetime) <= DATE(?)', @date)
      query_set = query_set.where('obs_datetime >= ?', @starting_from_date) if filter_by_outcome_date
      return query_set
    end

  end
end