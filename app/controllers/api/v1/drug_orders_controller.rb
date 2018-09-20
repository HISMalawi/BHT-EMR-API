# frozen_string_literal: true

require 'utils/remappable_hash'

class Api::V1::DrugOrdersController < ApplicationController
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

    orders, errors = create_drug_orders encounter: encounter,
                                        drug_orders: drug_orders
    if errors
      render json: orders, status: :bad_request
    else
      render json: orders, status: :created
    end
  end

  def update
    quantity_updates = params.require :drug_orders

    orders, error = update_drug_orders quantity_updates

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

  private

  # Creates a new drug order.
  #
  # Returns null if successful else an error object
  def create_drug_orders(encounter:, drug_orders:)
    ActiveRecord::Base.transaction do
      order_type = OrderType.find_by_name('Drug Order')

      drug_orders = drug_orders.collect do |drug_order|
        order = create_order encounter: encounter, create_params: drug_order,
                             order_type: order_type
        return [order.errors, true] unless order.errors.empty?

        drug_order = create_drug_order order: order, create_params: drug_order
        return [drug_order.errors, true] unless drug_order.errors.empty?

        drug_order
      end

      [drug_orders, false]
    end
  end

  def create_order(encounter:, create_params:, order_type:)
    Order.create(
      order_type_id: order_type.order_type_id,
      concept_id: Drug.find(create_params[:drug_inventory_id]).concept_id,
      encounter_id: encounter.encounter_id,
      patient_id: encounter.patient_id,
      orderer: User.current.user_id,
      start_date: create_params[:start_date],
      auto_expire_date: create_params[:auto_expire_date],
      obs_id: create_params[:obs_id],
      instructions: create_params[:instructions]
    )
  end

  def create_drug_order(order:, create_params:)
    drug = Drug.find(create_params[:drug_inventory_id])

    DrugOrder.create(
      drug_inventory_id: drug.drug_id,
      order_id: order.id,
      dose: create_params[:dose],
      frequency: create_params[:frequency],
      prn: create_params[:prn] || 0,
      units: create_params[:units] || drug.units,
      equivalent_daily_dose: create_params[:equivalent_daily_dose],
      quantity: create_params[:quantity] || 0
    )
  end

  def update_drug_orders(quantity_updates)
    # TODO: Update more than just quantity
    ActiveRecord::Base.transaction do
      orders = quantity_updates.collect do |update|
        order = DrugOrder.find(update[:order_id])
        order.quantity = update[:quantity].to_i
        order.save! # Any errors here aren't of our doing...
        order
      end

      return orders, false
    end
  end
end
