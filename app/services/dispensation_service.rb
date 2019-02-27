# frozen_string_literal: true

module DispensationService
  class << self
    include ModelUtils

    def dispensations(patient_id, date = nil)
      concept_id = concept('AMOUNT DISPENSED').concept_id

      if date
        Observation.where(
          person_id: patient_id, concept_id: concept_id
        ).where(
          'DATE(obs_datetime) = DATE(?)', date
        ).order(date_created: :desc)
      else
        Observation.where(
          person_id: patient_id, concept_id: concept_id
        ).order(date_created: :desc)
      end
    end

    def create(program, plain_dispensations)
      ActiveRecord::Base.transaction do
        obs_list = plain_dispensations.map do |dispensation|
          order_id = dispensation[:drug_order_id]
          quantity = dispensation[:quantity]
          date = TimeUtils.retro_timestamp(dispensation[:date]&.to_time || Time.now)
          drug_order = DrugOrder.find(order_id)
          obs = dispense_drug program, drug_order, quantity, date: date

          unless obs.errors.empty?
            raise InvalidParameterErrors.new("Failed to dispense order ##{order_id}")\
                                        .add_model_errors(model_errors)
          end

          obs.as_json.tap { |hash| hash[:amount_needed] = drug_order.amount_needed }
        end

        obs_list
      end
    end

    def dispense_drug(program, drug_order, quantity, date: nil)
      date ||= Time.now
      patient = drug_order.order.patient
      encounter = current_encounter program, patient, date: date, create: true

      drug_order.quantity ||= 0
      drug_order.quantity += quantity.to_f
      drug_order.save

      # HACK: Change state of patient in HIV Program to 'On anteretrovirals'
      # once ARV's are detected. This should be moved away from here.
      # It is behaviour that could potentially be surprising to our clients...
      # Let's avoid surprises, clients must explicitly trigger the state change.
      # Besides this service is open to different clients, some (actually most)
      # are not even interested in the HIV Program... So...
      mark_patient_as_on_antiretrovirals(patient, date) if drug_order.drug.arv?

      Observation.create(
        concept_id: concept('AMOUNT DISPENSED').concept_id,
        order_id: drug_order.order_id,
        person_id: patient.patient_id,
        encounter_id: encounter.encounter_id,
        value_drug: drug_order.drug_inventory_id,
        value_numeric: quantity,
        obs_datetime: date # TODO: Prefer date passed by user
      )
    end

    # Finds the most recent encounter for the given patient
    def current_encounter(program, patient, date: nil, create: false)
      date ||= Time.now
      encounter = find_encounter program, patient, date
      encounter ||= create_encounter program, patient, date if create
      encounter
    end

    # Creates a dispensing encounter
    def create_encounter(program, patient, date)
      Encounter.create(
        program: program,
        encounter_type: EncounterType.find_by(name: 'DISPENSING').encounter_type_id,
        patient_id: patient.patient_id,
        location_id: Location.current.location_id,
        encounter_datetime: date,
        provider: User.current.person
      )
    end

    # Finds a dispensing encounter for the given patient on the given date
    def find_encounter(program, patient, date)
      encounter_type = EncounterType.find_by(name: 'DISPENSING').encounter_type_id
      Encounter.where(
        'program_id = ? AND encounter_type = ? AND patient_id = ? AND DATE(encounter_datetime) = DATE(?)',
        program.id, encounter_type, patient.patient_id, date
      ).order(date_created: :desc).first
    end

    private

    # HACK: See dispense_drug methods
    def mark_patient_as_on_antiretrovirals(patient, date)
      program, patient_program = patient_hiv_program(patient)
      return unless program && patient_program

      program_workflow = program.program_workflows.first
      return unless program_workflow

      on_arvs_state = program_state(program_workflow, 'On antiretrovirals')
      transferred_out_state = program_state(program_workflow, 'Patient transferred out')

      current_patient_state = patient_current_state(patient_program, date)
      if patient_has_state?(patient_program, on_arvs_state)\
         && current_patient_state&.state != transferred_out_state.id
        return
      end

      mark_patient_art_start_date(patient, date)

      create_patient_state(patient_program, on_arvs_state, date, current_patient_state)
    end

    def patient_hiv_program(patient)
      program = patient.programs.where(name: 'HIV Program').first
      return [nil, nil] unless program

      patient_program = patient.patient_programs.where(program: program).first
      [program, patient_program]
    end

    def program_state(program_workflow, name)
      state_concept = concept(name)
      state = program_workflow.states.where(concept: state_concept).first
      raise "'#{name}' state for HIV Program not found" unless state

      state
    end

    def patient_current_state(patient_program, ref_date)
      PatientState.where(patient_program: patient_program)\
                  .where('start_date <= DATE(?)', ref_date.to_date)\
                  .last
    end

    def patient_has_state?(patient_program, workflow_state)
      patient_program.patient_states.where(
        program_workflow_state: workflow_state
      ).exists?
    end

    def mark_patient_art_start_date(patient, date)
      art_start_date_concept = concept('ART start date')
      return if Observation.where(person_id: patient.patient_id, concept: art_start_date_concept).exists?

      Observation.create person_id: patient.patient_id,
                         concept: art_start_date_concept,
                         value_datetime: date,
                         obs_datetime: TimeUtils.retro_timestamp(date)
    end

    def create_patient_state(patient_program, program_workflow_state, date, previous_state = nil)
      ActiveRecord::Base.transaction do
        if previous_state
          previous_state.end_date = date
          previous_state.save
        end

        PatientState.create(
          patient_program: patient_program,
          program_workflow_state: program_workflow_state,
          start_date: date
        )
      end
    end
  end
end
