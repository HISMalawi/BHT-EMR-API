# frozen_string_literal: true

module NeonatalService
  class WorkflowEngine
    include ModelUtils

    attr_reader :patient, :program, :date

    LOGGER = Rails.logger

    INITIAL_STATE = 0
    END_STATE = 1

    NEONATAL_ENROLLMENT = 'NEONATAL ENROLLMENT'
    VITALS = 'VITALS'
    NEONATAL_TRIAGE = 'NEONATAL TRIAGE'
    ASSESSMENT = 'ASSESSMENT'
    TREATMENT = 'TREATMENT'
    DISPENSING = 'DISPENSING'
    APPOINTMENT = 'APPOINTMENT'
    OUTCOME = 'OUTCOME'

    ENCOUNTER_SM = {
      INITIAL_STATE => NEONATAL_ENROLLMENT,
      NEONATAL_ENROLLMENT => VITALS,
      VITALS => NEONATAL_TRIAGE,
      NEONATAL_TRIAGE => ASSESSMENT,
      ASSESSMENT => TREATMENT,
      TREATMENT => DISPENSING,
      DISPENSING => APPOINTMENT,
      APPOINTMENT => OUTCOME,
      OUTCOME => END_STATE
    }.freeze

    STATE_CONDITIONS = {
      NEONATAL_ENROLLMENT => %i[patient_not_enrolled?],
      VITALS => %i[patient_has_no_vitals_today?],
      NEONATAL_TRIAGE => %i[patient_has_no_triage_today?],
      ASSESSMENT => %i[patient_has_no_assessment_today?],
      TREATMENT => %i[patient_has_no_treatment_today?],
      DISPENSING => %i[patient_has_no_dispensing_today? patient_needs_medication?],
      APPOINTMENT => %i[patient_has_no_appointment_today?],
      OUTCOME => %i[patient_has_no_outcome_today?]
    }.freeze

    def initialize(program:, patient:, date: nil)
      @patient = patient
      @program = program
      @date = date&.to_date || Date.today
      @activities = load_user_activities
    end

    def next_encounter
      state = INITIAL_STATE

      loop do
        state = next_state(state)
        break if state == END_STATE

        LOGGER.debug("Evaluating state: #{state}")

        if valid_state?(state)
          encounter_type = EncounterType.find_by(name: state)
          LOGGER.info("Next encounter for patient #{@patient.patient_id}: #{state}")
          return encounter_type
        end
      end

      LOGGER.info("No more encounters for patient #{@patient.patient_id}")
      nil
    end

    def remaining_encounters
      encounters = []
      state = INITIAL_STATE

      loop do
        state = next_state(state)
        break if state == END_STATE

        if valid_state?(state)
          encounter_type = EncounterType.find_by(name: state)
          encounters << encounter_type if encounter_type
        end
      end

      encounters
    end

    def workflow_complete?
      next_encounter.nil?
    end

    def encounters_today
      Encounter.joins(:type)
               .where(patient_id: @patient.patient_id, program_id: @program.program_id)
               .where('encounter_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(@date))
               .order(encounter_datetime: :asc)
    end

    def completed_encounters_today
      encounters_today.map { |e| e.type.name }.uniq
    end

    private

    def next_state(current_state)
      ENCOUNTER_SM[current_state]
    end

    def valid_state?(state)
      return false unless @activities.include?(state)
      encounter_type = EncounterType.find_by(name: state)
      return false if encounter_exists?(encounter_type)

      conditions = STATE_CONDITIONS[state] || []
      conditions.all? { |condition| method(condition).call }
    end

    def encounter_exists?(type)
      return false unless type

      Encounter.where(
        type: type,
        patient_id: @patient.patient_id,
        program_id: @program.program_id
      ).where('encounter_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(@date))
       .exists?
    end

    def patient_not_enrolled?
      !enrollment_engine.enrolled?
    end

    def patient_has_no_vitals_today?
      !encounter_exists?(encounter_type(VITALS))
    end

    def patient_has_no_triage_today?
      !encounter_exists?(encounter_type(NEONATAL_TRIAGE))
    end

    def patient_has_no_assessment_today?
      !encounter_exists?(encounter_type(ASSESSMENT))
    end

    def patient_has_no_treatment_today?
      !encounter_exists?(encounter_type(TREATMENT))
    end

    def patient_has_no_dispensing_today?
      !encounter_exists?(encounter_type(DISPENSING))
    end


    def patient_needs_medication?
      treatment_encounter = Encounter.joins(:type)
                                     .where(
                                       'encounter_type.name = ?', TREATMENT
                                     )
                                     .where(
                                       patient_id: @patient.patient_id,
                                       program_id: @program.program_id
                                     )
                                     .where('encounter_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(@date))
                                     .first

      return false unless treatment_encounter

      drug_orders_exist = Observation.joins(:concept)
                                     .where(encounter_id: treatment_encounter.encounter_id)
                                     .where('concept.concept_id IN (?)', drug_concept_ids)
                                     .exists?

      drug_orders_exist
    end

    def patient_has_no_appointment_today?
      !encounter_exists?(encounter_type(APPOINTMENT))
    end

    def patient_has_no_outcome_today?
      !encounter_exists?(encounter_type(OUTCOME))
    end

    def load_user_activities
      activities_property = user_property('neonatal.activities')&.property_value
      activities_property ||= 'Enrollment,Vitals,Triage,Assessment,Treatment,Dispensing,Appointment,Outcome'

      encounters = (activities_property.split(',') || []).map do |activity|
        case activity.strip
        when /Enrollment/i then NEONATAL_ENROLLMENT
        when /Vitals/i then VITALS
        when /Triage/i then NEONATAL_TRIAGE
        when /Assessment/i then ASSESSMENT
        when /Treatment/i then TREATMENT
        when /Dispensing/i then DISPENSING
        when /Appointment/i then APPOINTMENT
        when /Outcome/i then OUTCOME
        else
          LOGGER.warn("Invalid neonatal activity in user properties: #{activity}")
          nil
        end
      end.compact

      Set.new(encounters)
    end

    def drug_concept_ids
      @drug_concept_ids ||= begin
        concepts = [
          'Medication orders',
          'Drug',
          'Prescribe drug',
          'Medication'
        ].map { |name| concept(name)&.concept_id }.compact

        concepts.presence || []
      end
    end

    def enrollment_engine
      @enrollment_engine ||= NeonatalService::EnrollmentEngine.new(
        patient: @patient,
        program: @program,
        date: @date
      )
    end
  end
end
