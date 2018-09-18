# frozen_string_literal: true

require 'utils/remappable_hash'

class Api::V1::DrugOrdersController < ApplicationController
  # POST /drug_orders
  #
  # Required params:
  def create
    create_params = params.permit(
      :drug_inventory_id, :encounter_id, :patient_id, :start_date,
      :auto_expire_date, :frequency, :prn, :instructions,
      :equivalent_daily_dose, :dose, :units, :quantity
    )

    create_params[:encounter] = current_treatment_encounter(create_params[:patient_id])
    create_params[:units] = 'per day'
    create_params[:prn] = 0
    drug_order, error = create_drug_order(create_params)

    if error
      render json: drug_order, status: :bad_request
    else
      render json: drug_order, status: :created
    end
  end

  def update
    update_params = params.permit(
      :drug_inventory_id, :encounter_id, :patient_id, :start_date,
      :auto_expire_date, :frequency, :prn, :instructions,
      :equivalent_daily_dose, :dose, :units, :quantity
    )

    raise :not_implemented_error
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
  # Returns [drug_order, false] if successful else [errors, true]
  def create_drug_order(create_params)
    ActiveRecord::Base.transaction do
      order = Order.create(
        order_type_id: OrderType.find_by_name('Drug Order').order_type_id,
        concept_id: Drug.find(create_params[:drug_inventory_id]).concept_id,
        encounter_id: create_params[:encounter_id],
        orderer: User.current.user_id,
        patient_id: create_params[:patient_id],
        start_date: create_params[:start_date],
        auto_expire_date: create_params[:auto_expire_date],
        obs_id: create_params[:obs_id],
        instructions: create_params[:instructions]
      )

      break [order.errors, true] unless order.errors.empty?

      drug_order = DrugOrder.create(
        drug_inventory_id: create_params[:drug_inventory_id],
        order_id: order.id,
        dose: create_params[:dose],
        frequency: create_params[:frequency],
        prn: create_params[:prn],
        units: create_params[:units],
        equivalent_daily_dose: create_params[:equivalent_daily_dose]
      )

      drug_order.errors.empty? ? [drug_order, false] : [drug_order.errors, true]
    end
  end

  # Similar to create_drug_order above but updates rather than create
  def update_drug_order(drug_order, update_params)
    ActiveRecord::Base.transaction do
      order = drug_order.order
      # order.updae
    end
  end

  def current_treatment_encounter(patient_id, date: Time.now)
    type = EncounterType.find_by_name('TREATMENT')
    encounter = Encounter.where(
      [
        'patient_id = ? AND DATE(encounter_datetime) = DATE(?) AND encounter_type = ?',
        patient_id, date, type.id
      ]
    )

    if encounter.nil?
      return encounters.create encounter_type: type.id, encounter_datetime: date
    end

    encounter
  end
end
