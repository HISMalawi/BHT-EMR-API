# frozen_string_literal: true

module Lab
  # Search Lab orders.
  module OrdersSearchService
    class << self
      def find_orders(filters)
        date = filters.delete(:date)
        status = filters.delete(:status)

        orders = Lab::LabOrder.prefetch_relationships
                              .where(filters)
                              .order(start_date: :desc)

        orders = filter_orders_by_date(orders, date) if date
        orders = filter_orders_by_status(orders, status) if status

        orders.map { |order| Lab::LabOrderSerializer.serialize_order(order) }
      end

      def filter_orders_by_date(orders, date)
        orders.where('start_date < DATE(?)', date.to_date + 1.day)
      end

      def filter_orders_by_status(orders, status)
        case status.downcase
        when 'ordered' then orders.where(concept_id: unknown_concept_id)
        when 'drawn' then orders.where.not(concept_id: unknown_concept_id)
        end
      end

      def unknown_concept_id
        ConceptName.find_by_name!('Unknown').concept_id
      end

      def filter_orders_by_status(orders, status)
        case status.downcase
        when 'ordered' then orders.where(concept_id: unknown_concept_id)
        when 'drawn' then orders.where.not(concept_id: unknown_concept_id)
        end
      end

      def unknown_concept_id
        ConceptName.find_by_name!('Unknown').concept_id
      end
    end
  end
end
