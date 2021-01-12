# frozen_string_literal: true

module ARTService
  # Responsible for dealing with patient state changes in HIV program.
  class PatientStateEngine
    attr_accessor :patient, :date

    include ModelUtils

    def initialize(patient, date)
      @patient = patient
      @date = date
    end

    # Listener for drug dispensations under HIV Program.
    #
    # This is automatically called by the DispensationService when
    # drugs are dispensed under the HIV program.
    def on_drug_dispensation(drug_order, _amount_dispensed)
      return nil unless patient_program && arv_drug_order?(drug_order)

      on_arvs_state = program.state('On antiretrovirals')

      patient_state = patient_program.current_state(date)
      return if patient_state&.state == on_arvs_state.id

      ActiveRecord::Base.transaction do
        unless patient_has_state?(patient_program, on_arvs_state)
          mark_patient_art_start_date(patient)
        end

        create_patient_state(on_arvs_state, date, patient_state)
      end
    end

    private

    def program
      return @program if @program

      @program = Program.find_by_name('HIV Program')
      raise 'Missing HIV Program in database' unless @program

      @program
    end

    def patient_program
      @patient_program ||= patient.patient_programs.where(program: program).first
    end

    def arv_drug_order?(drug_order)
      Drug.arv_drugs.where(drug_id: drug_order.drug_inventory_id).exists?
    end

    def patient_has_state?(patient_program, workflow_state)
      patient_program.patient_states
                     .where('start_date <= ? AND state = ?', date, workflow_state.id)
                     .order(:start_date)
                     .exists?
    end

    def mark_patient_art_start_date(patient)
      art_start_date_concept = concept('ART start date')
      has_art_start_date = Observation.where(person_id: patient.patient_id,
                                             concept: art_start_date_concept)
                                      .exists?
      return if has_art_start_date

      Observation.create(person_id: patient.patient_id,
                         concept: art_start_date_concept,
                         value_datetime: date,
                         obs_datetime: TimeUtils.retro_timestamp(date))
    end

    def create_patient_state(program_workflow_state, date, previous_state = nil)
      previous_state&.update(end_date: date)

      if patient.person.dead || patient.person.death_date
        # Resurrection!!! Gill would be proud...
        patient.person.update(dead: false, death_date: nil)
      end

      PatientState.create(
        patient_program: patient_program,
        program_workflow_state: program_workflow_state,
        start_date: date
      )
    end
  end
end
