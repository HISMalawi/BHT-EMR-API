# frozen_string_literal: true

require 'utils/remappable_hash'

class Api::V1::DrugOrdersController < ApplicationController
  def index
    patient_id = params.require %i[patient_id]

    if params[:date]
      date = params[:date] ? Date.strptime(params[:date]) : Time.now
      treatment = EncounterService.recent_encounter encounter_type_name: 'Treatment',
                                                    patient_id: patient_id,
                                                    date: date
      orders = treatment ? paginate(treatment.orders) : []
    else
      orders = paginate(Order.where(patient_id: patient_id).order(date_created: :desc))
    end

    drug_orders = orders.map(&:drug_order).reject(&:nil?)

    render json: drug_orders
  end

  # POST /drug_orders
  #
  # Create drug orders in bulk
  #
  # Required params:
  def create
    encounter_id, drug_orders = params.require(%i[encounter_id drug_orders])

    encounter = Encounter.find(encounter_id)
    unless encounter.type.name == 'TREATMENT'
      return render json: { errors: "Not a treatment encounter ##{encounter.encounter_id}" },
                    status: :bad_request
    end

    orders = DrugOrderService.create_drug_orders encounter: encounter,
                                                 drug_orders: drug_orders
    render json: orders, status: :created
  end

  def update
    quantity_updates = params.require :drug_orders

    orders, error = DrugOrderService.update_drug_orders quantity_updates

    if error
      render json: error, status: :bad_request if error
    else
      render json: orders, status: :created
    end
  end

  def destroy
    DrugOrder.find(params[:id])

    if drug_order.void
      render status: :no_content
    else
      render json: drug_order.errors, status: :internal_server_error
    end
  end
end
