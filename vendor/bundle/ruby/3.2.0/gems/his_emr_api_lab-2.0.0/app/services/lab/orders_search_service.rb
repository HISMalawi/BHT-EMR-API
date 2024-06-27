# frozen_string_literal: true

module Lab
  # Search Lab orders.
  module OrdersSearchService
    class << self
      def find_orders(filters)
        extra_filters = pop_filters(filters, :date, :end_date, :status)

        orders = Lab::LabOrder.prefetch_relationships
                              .where(filters)
                              .order(start_date: :desc)

        orders = filter_orders_by_status(orders, **pop_filters(extra_filters, :status))
        orders = filter_orders_by_date(orders, **extra_filters)

        orders.map { |order| Lab::LabOrderSerializer.serialize_order(order) }
      end

      def find_orders_without_results(patient_id: nil)
        results_query = Lab::LabResult.all
        results_query = results_query.where(person_id: patient_id) if patient_id

        query = Lab::LabOrder.where.not(order_id: results_query.select(:order_id))
        query = query.where(patient_id:) if patient_id

        query
      end

      def filter_orders_by_date(orders, date: nil, end_date: nil)
        date = date&.to_date
        end_date = end_date&.to_date

        return orders.where('start_date BETWEEN ? AND ?', date, end_date + 1.day) if date && end_date

        return orders.where('start_date BETWEEN ? AND ?', date, date + 1.day) if date

        return orders.where('start_date < ?', end_date + 1.day) if end_date

        orders
      end

      def filter_orders_by_status(orders, status: nil)
        case status&.downcase
        when 'ordered' then orders.where(concept_id: unknown_concept_id)
        when 'drawn' then orders.where.not(concept_id: unknown_concept_id)
        else orders
        end
      end

      def unknown_concept_id
        ConceptName.find_by_name!('Unknown').concept_id
      end

      def pop_filters(params, *filters)
        filters.each_with_object({}) do |filter, popped_params|
          next unless params.key?(filter)

          popped_params[filter.to_sym] = params.delete(filter)
        end
      end

      def fetch_results(order); end
    end
  end
end
