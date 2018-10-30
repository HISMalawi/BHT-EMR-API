# frozen_string_literal: true

module DrugOrderService
  class << self
    # Creates drug orders in bulk.
    #
    # Returns [drug_order, false] if successful else [null, true]
    #
    # Parameters:
    #   - encounter: Is the encounter to attach the drug_orders to
    #   - plain_orders: An array of create_params (see below).
    #
    #  create_params:
    #    {
    #       drug_inventory_id: ...,
    #       start_date: ...,
    #       auto_expire_date: ...,
    #       obs_id: ...,
    #       instructions: ...,
    #       dose: ...,
    #       frequency: ...,
    #       prn: ...,
    #       units: ...,   // Can be omitted
    #       equivalent_daily_dose: ...,
    #       quantity: ... // Can be omitted
    #    }
    def create_drug_orders(encounter:, drug_orders:)
      ActiveRecord::Base.transaction do
        order_type = OrderType.find_by_name('Drug Order')

        saved_drug_orders = []

        drug_orders.each_with_index do |drug_order, i|
          order = create_order encounter: encounter, create_params: drug_order,
                               order_type: order_type
          unless order.errors.empty?
            raise_model_error(order, "Unable to create order #{i}")
          end

          drug_order = create_drug_order order: order, create_params: drug_order
          unless drug_order.errors.empty?
            raise_model_error(drug_order, "Unable to create drug order #{i}")
          end

          saved_drug_orders << drug_order
        end

        saved_drug_orders
      end
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

    private

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

    def drug_quantity(_drug, create_params)
      auto_expire_date = Date.strptime(create_params[:auto_expire_date])
      start_date = Date.strptime(create_params[:start_date])
      duration = auto_expire_date - start_date
      duration.to_i * create_params[:equivalent_daily_dose].to_i
    end

    def raise_model_error(model, prefix)
      errors = model.errors.map { |k, v| "#{k}: #{v}" }.join(', ')
      raise InvalidParameterError, "#{prefix}: #{errors}"
    end
  end
end
