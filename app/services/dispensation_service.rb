module DispensationService
  class << self
    def create(plain_dispensations)
      obs_list = plain_dispensations.map do |dispensation|
        order_id = dispensation[:drug_order_id]
        quantity = dispensation[:quantity]
        date = dispensation[:date] ? Time.strptime(dispensation[:date]) : nil
        obs = dispense_drug order_id, quantity, date: date
        unless obs.errors.empty?
          return ["Failed to dispense order ##{order_id}", obs.errors], true
        end
        obs
      end

      [obs_list, false]
    end

    def dispense_drug(order_id, quantity, date: nil)
      date ||= Time.now
      drug_order = DrugOrder.find(order_id)
      # NOTE: Some caching below would be helpful
      patient = drug_order.order.patient
      encounter = current_encounter patient, create: true

      drug_order.quantity ||= 0
      drug_order.quantity += quantity
      drug_order.save

      Observation.create(
        concept_id: concept('AMOUNT DISPENSED').concept_id,
        order_id: order_id,
        person_id: patient.patient_id,
        encounter_id: encounter.encounter_id,
        value_drug: drug_order.drug_inventory_id,
        value_numeric: quantity,
        obs_datetime: date # TODO: Prefer date passed by user
      )
    end

    # Finds the most recent encounter for the given patient
    def current_encounter(patient, date: nil, create: false)
      date ||= Time.now
      encounter = find_encounter patient, date
      encounter ||= create_encounter patient, date if create
      encounter
    end

    # Creates a dispensing encounter
    def create_encounter(patient, date)
      Encounter.create(
        encounter_type: EncounterType.find_by(name: 'DISPENSING').encounter_type_id,
        patient_id: patient.patient_id,
        location_id: Location.current.id,
        encounter_datetime: date,
        provider: User.current
      )
    end

    # Finds a dispensing encounter for the given patient on the given date
    def find_encounter(patient, date)
      encounter_type = EncounterType.find_by(name: 'DISPENSING').encounter_type_id
      Encounter.where(
        'encounter_type = ? AND patient_id = ? AND DATE(encounter_datetime) = DATE(?)',
        encounter_type, patient.patient_id, date
      ).order(date_created: :desc).first
    end

    private

    def concept(name)
      concept_name = ConceptName.find_by(name: name)
      return nil unless concept_name
      Concept.find(concept_name.concept_id)
    end
  end
end
