# frozen_string_literal: true

module DispensationService
  class << self
    include ModelUtils

    def dispensations(patient_id, date = nil)
      concept_id = concept('AMOUNT DISPENSED').concept_id

      if date
        Observation.where(person_id: patient_id, concept_id: concept_id)
                   .where('DATE(obs_datetime) = DATE(?)', date)
                   .order(date_created: :desc)
      else
        Observation.where(person_id: patient_id, concept_id: concept_id)
                   .order(date_created: :desc)
      end
    end

    def create(program, plain_dispensations, provider = nil)
      ActiveRecord::Base.transaction do
        obs_list = plain_dispensations.map do |dispensation|
          order_id = dispensation[:drug_order_id]
          quantity = dispensation[:quantity]
          date = TimeUtils.retro_timestamp(dispensation[:date]&.to_time || Time.now)
          drug_order = DrugOrder.find(order_id)
          obs = dispense_drug(program, drug_order, quantity, date: date, provider: provider)

          unless obs.errors.empty?
            raise InvalidParameterErrors.new("Failed to dispense order ##{order_id}")\
                                        .add_model_errors(model_errors)
          end

          obs.as_json.tap { |hash| hash[:amount_needed] = drug_order.amount_needed }
        end

        obs_list.each { |obs| update_stock_ledgers(:process_dispensation, obs['obs_id']) }

        obs_list
      end
    end

    def dispense_drug(program, drug_order, quantity, date: nil, provider: nil)
      date ||= Time.now
      patient = drug_order.order.patient
      encounter = current_encounter(program, patient, date: date, create: true, provider: provider)

      ActiveRecord::Base.transaction do
        update_quantity_dispensed(drug_order, quantity)

        # HACK: Change state of patient in HIV Program to 'On anteretrovirals'
        # once ARV's are detected. This should be moved away from here.
        # It is behaviour that could potentially be surprising to our clients...
        # Let's avoid surprises, clients must explicitly trigger the state change.
        # Besides this service is open to different clients, some (actually most)
        # are not even interested in the HIV Program... So...
        if drug_order.drug.arv?
          ProgramEngineLoader.load(program, 'PatientStateEngine')
                             &.new(patient, date)
                             &.on_drug_dispensation(drug_order, quantity)
        end

        observation = Observation.create(
          concept_id: concept('AMOUNT DISPENSED').concept_id,
          order_id: drug_order.order_id,
          person_id: patient.patient_id,
          encounter_id: encounter.encounter_id,
          value_drug: drug_order.drug_inventory_id,
          value_numeric: quantity,
          obs_datetime: date
        )

        observation
      end
    end

    def void_dispensations(drug_order)
      voided_dispensations = ActiveRecord::Base.transaction do
        observations = lambda do |concept_names|
          concepts = ConceptName.where(name: concept_names).select(:concept_id)
          Observation.where(order_id: drug_order.id, concept: concepts)
        end

        voided_observations = observations['Amount dispensed'].map do |dispensation|
          dispensation.void("Dispensation reversed by #{User.current.username}", skip_after_void: true)

          dispensation
        end

        # Get clinician specified drug run out date...
        run_out_date = observations['Drug end date'].first
        drug_order.order.update!(auto_expire_date: run_out_date.value_datetime) if run_out_date
        drug_order.quantity = 0
        drug_order.save!

        voided_observations
      end

      voided_dispensations.each { |dispensation| update_stock_ledgers(:reverse_dispensation, dispensation.id) }
    end

    # Updates the quantity dispensed of the drug_order and adjusts
    # the auto_expiry_date if necessary
    def update_quantity_dispensed(drug_order, quantity)
      drug_order.quantity ||= 0
      drug_order.quantity += quantity.to_f

      order = drug_order.order
      # We assume patient start taking drugs on same day he/she receives them
      # thus we subtract 1 from the duration.
      quantity_duration = drug_order.quantity_duration - 1
      order.auto_expire_date = order.start_date + quantity_duration.days
      order.save

      drug_order.save
    end

    # Finds the most recent encounter for the given patient
    def current_encounter(program, patient, date: nil, create: false, provider: nil)
      date ||= Time.now
      encounter = find_encounter(program, patient, date)
      return encounter if encounter || !create

      create_encounter(program, patient, date, provider)
    end

    # Creates a dispensing encounter
    def create_encounter(program, patient, date, provider = nil)
      Encounter.create(
        encounter_type: EncounterType.find_by(name: 'DISPENSING').encounter_type_id,
        patient_id: patient.patient_id,
        location_id: Location.current.location_id,
        encounter_datetime: date,
        program: program,
        provider: provider || User.current.person
      )
    end

    # Finds a dispensing encounter for the given patient on the given date
    def find_encounter(program, patient, date)
      encounter_type = EncounterType.find_by(name: 'DISPENSING').encounter_type_id
      Encounter.where(program_id: program.id,
                      encounter_type: encounter_type,
                      patient_id: patient.id)
               .where('DATE(encounter_datetime) = DATE(?)', date)
               .order(date_created: :desc)
               .first
    end

    def update_stock_ledgers(action, observation_id)
      StockUpdateJob.perform_later(action.to_s, user_id: User.current.id,
                                                location_id: Location.current.id,
                                                dispensation_id: observation_id)
    end
  end
end
