class Api::V1::DispatchOrdersController < ApplicationController
  def index
  end

	def show
    order = Observation.find_by(order_id: params[:order_id],
		 concept_id: ConceptName.find_by_name('Lab follow-up').concept_id)
		render json: order, status: 200
	end

  def create
    order = Order.find(params[:order_id])
		obs = []
		ActiveRecord::Base.transaction do
			encounter = Encounter.create(patient_id: order.patient_id,
			encounter_type: EncounterType.find_by_name('SCREENING').id, encounter_datetime: Time.now(), program_id: 13)
			obs = Observation.create(person_id: order.patient_id,
			obs_datetime: encounter.encounter_datetime,
			concept_id: ConceptName.find_by_name('Lab follow-up').concept_id,
			value_numeric: params[:location_id],
			encounter_id: encounter.id,
			value_datetime: params[:dispatch_date],
			value_text: params[:responsible_person])
		end
		render json: obs, status: (obs.blank? ? 500 : 200)
  end

end
