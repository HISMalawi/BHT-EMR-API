# frozen_string_literal: true

module DrugOrderService
  ORDER_PARAMS = %i[order_type_id concept_id orderer encounter_id start_date
                    auto_expire_date discontinued_date patient_id
                    accession_number obs_id program_id].freeze

  DRUG_ORDER_PARAMS = %i[drug_inventory_id].freeze

  FIND_FILTERS = ORDER_PARAMS + DRUG_ORDER_PARAMS

  DATETIME_FIELDS = %i[start_date auto_expire_date discontinued_date].freeze

  class << self
    def find(filters)
      date = filters.delete(:date)&.to_date
      program_id = filters.delete(:program_id)

      query = DrugOrder.joins(:order).where(*parse_search_filters(filters))

      if date || program_id
        encounter_query = Encounter.all

        encounter_query = encounter_query.where('encounter_datetime BETWEEN ? AND ?', date, date + 1.day) if date
        encounter_query = encounter_query.where(program_id: program_id) if program_id

        query = query.merge(Order.joins(:encounter).merge(encounter_query))
      end

      query
    end

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

    def parse_search_filters(filters)
      query_cond = []
      query_params = []

      filters.each do |k, v|
        k = k.to_sym
        if ORDER_PARAMS.include?(k)
          if DATETIME_FIELDS.include?(k)
            query_cond << "`orders`.`#{k}` BETWEEN ? AND ?"
            query_params.concat(TimeUtils.day_bounds(v.to_date))
          else
            query_cond << "`orders`.`#{k}` = ?"
            query_params << v
          end
        elsif DRUG_ORDER_PARAMS.include?(k)
          query_cond << "`drug_order`.`#{k}` = ?"
          query_params << v
        else
          raise InvalidParameterError, "Invalid parameter for drug order: #{k}"
        end
      end

      [query_cond.join(' AND ')] + query_params
    end

    def create_order(encounter:, create_params:, order_type:)
      start_date = TimeUtils.retro_timestamp(create_params[:start_date].to_date)
      drug_runout_date = TimeUtils.retro_timestamp(create_params[:auto_expire_date].to_date)

      order = Order.create(
        order_type_id: order_type.order_type_id,
        concept_id: Drug.find(create_params[:drug_inventory_id]).concept_id,
        encounter_id: encounter.encounter_id,
        patient_id: encounter.patient_id,
        orderer: User.current.user_id,
        start_date: start_date,
        auto_expire_date: drug_runout_date,
        obs_id: create_params[:obs_id],
        instructions: create_params[:instructions]
      )

      # Store user specified drug run out date separately as it is overriden
      # based on the drugs that actually get dispensed.
      Observation.create!(concept_id: ConceptName.find_by_name!('Drug end date').concept_id,
                          encounter: encounter,
                          person_id: encounter.patient_id,
                          order: order,
                          obs_datetime: start_date,
                          value_datetime: drug_runout_date,
                          comments: 'User specified drug run out date during drug prescription')

      order
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
