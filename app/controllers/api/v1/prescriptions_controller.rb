class Api::V1::PrescriptionsController < ApplicationController
  # GET /prescriptions
  #
  # Retrieves encounters of type prescription
  #
  # Optional parameters:
  #   patient_id, provider
  def index
    filters = params.permit(:patient_id, :provider)
    filters[:encounter_type] = EncounterType.find_by_name('Treatment').encounter_type_id
    render json: paginate(Encounter.where(filters))
  end

  def create
    orders = params.require :orders

    patient = DrugOrder.find(orders[0]).order.patient
    encounter, error = create_prescription drug_orders: orders

    if error
      render json: encounter, status: :bad_request
    else
      render json: encounter, status: :created
    end
  end

  private

  def create_prescription(drug_orders:)
    patient = DrugOrder.find(drug_orders[0]).order.patient

    ActiveRecord::Base.transaction do
      encounter = create_treatment_encounter patient: patient
      return [encounter.errors, true] unless encounter.errors.empty?

      drug_orders.each do |order|
        drug_order = DrugOrder.find(order)

        if drug_order.order.patient != patient
          return [{ errors: ['Drug orders belong to different patients'] }, true]
        end

        obs = create_treatment_observation drug_order: drug_order,
                                           encounter: encounter
        return [obs.errors, true] unless obs.errors.empty?
      end

      [encounter, false]
    end
  end

  def create_treatment_encounter(patient:)
    Encounter.create(
      encounter_type: EncounterType.find_by_name('Treatment').encounter_type_id,
      patient_id: patient.patient_id,
      provider: params[:provider] || User.current,
      location_id: Location.current.location_id,
      encounter_datetime: params[:encounter_datetime] || Time.now
    )
  end

  def create_treatment_observation(drug_order:, encounter:)
    Observation.create(
      concept_id: ConceptName.find_by_name('Amount dispensed').concept_id,
      value_drug: drug_order.drug_inventory_id,
      encounter_id: encounter.encounter_id,
      order_id: drug_order.order_id,
      person_id: encounter.patient_id,
      obs_datetime: encounter.encounter_datetime,
      comments: 'Prescription made  ',
      location_id: Location.current.location_id
    )
  end
end
