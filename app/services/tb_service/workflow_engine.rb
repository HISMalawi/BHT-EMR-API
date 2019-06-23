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
    # FOLLOW - TB INITIAL, LAB ORDERS. LAB RESULTs, VITALS, TREATMENT, DISPENSING, APPOINTMENT, TB ADHERENCE

    # CONCEPTS
    YES = 1065

    # Ask vitals when TB Positive
    # Diagnosis is for minors under and equal to 5 and suspsets over who are TB on the first encounter negative
    #

    # Encounters graph
    ENCOUNTER_SM = {
      INITIAL_STATE => TB_INITIAL,
      TB_INITIAL => LAB_ORDERS,
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
                                    patient_not_transferred_in_today?],

      LAB_ORDERS => %i[patient_should_go_for_lab_order?
                                    patient_not_transferred_in_today?],
      TB_ADHERENCE => %i[patient_has_appointment?
                                    patient_has_no_adherence?
                                    patient_has_valid_test_results?],
      TREATMENT => %i[patient_should_get_treated?
                                    patient_diagnosed?
                                    patient_has_no_treatment?
                                    patient_has_valid_test_results?
                                    patient_examined?],
      DISPENSING => %i[patient_got_treatment?
                                    patient_should_get_treated?
                                    patient_diagnosed?
                                    patient_has_no_dispensation?
                                    patient_has_valid_test_results?
                                    patient_examined?],
      DIAGNOSIS => %i[should_patient_tested_through_diagnosis?
                                    patient_has_no_diagnosis?
                                    patient_diagnosed?
                                    patient_not_transferred_in_today?],
      LAB_RESULTS => %i[patient_has_no_lab_results?
                                    patient_should_proceed_after_lab_order?
                                    patient_recent_lab_order_has_no_results?
                                    patient_not_transferred_in_today?],
      TB_RECEPTION => %i[patient_has_no_tb_reception?
                                    patient_diagnosed?
                                    patient_examined?
                                    patient_should_get_treated?],
      TB_REGISTRATION => %i[patient_has_no_tb_registration?
                                    patient_diagnosed?
                                    patient_examined?
                                    patient_is_not_a_transfer_out?
                                    patient_should_get_treated?],
      VITALS => %i[patient_has_no_vitals?
                                    patient_should_get_treated?
                                    patient_diagnosed?
                                    patient_has_valid_test_results?],
      APPOINTMENT => %i[dispensing_complete?
                                    patient_is_not_a_transfer_out?
                                    patient_diagnosed?
                                    patient_has_no_appointment?
                                    patient_has_valid_test_results?
                                    patient_examined?]
    }.freeze

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
        'encounter_type.name = ? AND encounter.patient_id = ?',
        TB_INITIAL,
        @patient.patient_id
      ).order(encounter_datetime: :desc).first.nil?
    end

    def patient_labs_not_ordered?
      Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ?',
        LAB_ORDERS,
        @patient.patient_id
      ).order(encounter_datetime: :desc).first.nil?
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

    def patient_should_get_treated?
      (patient_is_a_minor? && patient_current_tb_status_is_negative?) || patient_current_tb_status_is_positive?
    end

    def patient_has_no_lab_results?
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
        'encounter_type.name = ? AND encounter.patient_id = ?',
        LAB_ORDERS,
        @patient.patient_id
      ).order(encounter_datetime: :desc).first

      begin
        time_diff = (Time.current  - encounter.encounter_datetime)
        hours = (time_diff / 1.hour)
        (hours >= 1/60/60)
      rescue
        false
      end

    end

    def patient_recent_lab_order_has_no_results?
      lab_order = Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ?',
        LAB_ORDERS,
        @patient.patient_id
      ).order(encounter_datetime: :desc).first

      lab_result = Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ?',
        LAB_RESULTS,
        @patient.patient_id
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
        'encounter_type.name = ? AND encounter.patient_id = ?',
        DISPENSING,
        @patient.patient_id
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
        'encounter_type.name = ? AND encounter.patient_id = ?',
        LAB_ORDERS,
        @patient.patient_id
      ).order(encounter_datetime: :desc).first

      lab_result = Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ?',
        LAB_RESULTS,
        @patient.patient_id
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
        'encounter_type.name = ? AND encounter.patient_id = ?',
        DIAGNOSIS,
        @patient.patient_id
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
      examination_type = concept 'Laboratory examinations'
      Observation.where(
        "person_id = ? AND concept_id = ? AND value_coded = ? AND DATE(obs_datetime) = DATE(?)",
        @patient.patient_id, procedure_type.concept_id, examination_type.concept_id, @date
      ).order(obs_datetime: :desc).first.present?
    end

    def should_patient_tested_through_diagnosis?
      procedure_type = concept 'Procedure type'
      x_ray = concept 'Xray'
      clinical = concept 'Clinical'
      ultrasound = concept 'Ultrasound'
      Observation.where(
        "person_id = ? AND concept_id = ? AND (value_coded = ? || value_coded = ? || value_coded = ?) AND DATE(obs_datetime) = DATE(?)",
        @patient.patient_id, procedure_type.concept_id, x_ray.concept_id, clinical.concept_id, ultrasound.concept_id, @date
      ).order(obs_datetime: :desc).first.present?
    end

    def patient_has_no_adherence?
      Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ? AND DATE(encounter_datetime) = DATE(?)',
        TB_ADHERENCE,
        @patient.patient_id,
        @date
      ).order(encounter_datetime: :desc).first.nil?
    end

    def patient_has_no_treatment?
      Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ? AND DATE(encounter_datetime) = DATE(?)',
        TREATMENT,
        @patient.patient_id,
        @date
      ).order(encounter_datetime: :desc).first.nil?
    end

    def patient_has_no_dispensation?
      Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ? AND DATE(encounter_datetime) = DATE(?)',
        DISPENSING,
        @patient.patient_id,
        @date
      ).order(encounter_datetime: :desc).first.nil?
    end

    def patient_has_no_appointment?
      Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ? AND DATE(encounter_datetime) = DATE(?)',
        APPOINTMENT,
        @patient.patient_id,
        @date
      ).order(encounter_datetime: :desc).first.nil?
    end

    def patient_has_no_diagnosis?
      Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ? AND DATE(encounter_datetime) = DATE(?)',
        DIAGNOSIS,
        @patient.patient_id,
        @date
      ).order(encounter_datetime: :desc).first.nil?
    end

    def patient_has_lab_results?
      Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ? AND DATE(encounter_datetime) = DATE(?)',
        LAB_RESULTS,
        @patient.patient_id,
        @date
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
        'encounter_type.name = ? AND encounter.patient_id = ? AND DATE(encounter_datetime) = DATE(?)',
        TB_ADHERENCE,
        @patient.patient_id,
        @date
      ).order(encounter_datetime: :desc).first.present?
    end

    def patient_examined?
      patient_has_tb_results_today? || patient_has_adherence?
    end

    def patient_has_no_tb_registration?
      Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ?',
        TB_REGISTRATION,
        @patient.patient_id
      ).order(encounter_datetime: :desc).first.nil?
    end

    def patient_has_no_tb_reception?
      Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ? AND DATE(encounter_datetime) = DATE(?)',
        TB_RECEPTION,
        @patient.patient_id,
        @date
      ).order(encounter_datetime: :desc).first.nil?
    end

    def patient_current_tb_status_is_negative?
      status_concept = concept('TB status')
      negative_concept = concept('Negative')
      negative_status = Observation.where(
        'person_id = ? AND concept_id = ?',
        @patient.patient_id, status_concept.concept_id
      ).order(obs_datetime: :desc).first

      begin
        (negative_status.value_coded == negative_concept.concept_id)
      rescue
        false
      end

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
      transfer_in_concept = concept('Transfer in')
      yes_concept = concept 'YES'
      Observation.where(
        'person_id = ? AND concept_id = ? AND value_coded = ? AND DATE(obs_datetime) = DATE(?)',
        @patient.patient_id, transfer_in_concept.concept_id, yes_concept.concept_id, @date
      ).order(obs_datetime: :desc).first.nil?
    end
  end
end
