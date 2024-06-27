# frozen_string_literal: true

module Lab
  module Lims
    ##
    # Pushes all local orders to a LIMS Api object.
    class PushWorker
      attr_reader :lims_api

      include Utils # for logger

      SECONDS_TO_WAIT_FOR_ORDERS = 30

      def initialize(lims_api)
        @lims_api = lims_api
      end

      def push_orders(batch_size: 1000, wait: false)
        loop do
          logger.info('Looking for new orders to push to LIMS...')
          orders = orders_pending_sync(batch_size).all

          logger.debug("Found #{orders.size} orders...")
          orders.each do |order|
            push_order(order)
          rescue GatewayError => e
            logger.error("Failed to push order ##{order.accession_number}: #{e.class} - #{e.message}")
          end

          break unless wait

          logger.info('Waiting for orders...')
          sleep(Lab::Lims::Config.updates_poll_frequency)
        end
      end

      def push_order_by_id(order_id)
        order = Lab::LabOrder.joins(order_type: { name: 'Lab' })
                             .unscoped
                             .find(order_id)
        push_order(order)
      end

      ##
      # Pushes given order to LIMS queue
      def push_order(order)
        logger.info("Pushing order ##{order.order_id}")

        order_dto = Lab::Lims::OrderSerializer.serialize_order(order)
        mapping = Lab::LimsOrderMapping.find_by(order_id: order.order_id)

        ActiveRecord::Base.transaction do
          if mapping && !order.voided.zero?
            Rails.logger.info("Deleting order ##{order_dto[:accession_number]} from LIMS")
            lims_api.delete_order(mapping.lims_id, order_dto)
            mapping.destroy
          elsif mapping
            Rails.logger.info("Updating order ##{order_dto[:accession_number]} in LIMS")
            lims_api.update_order(mapping.lims_id, order_dto)
            if order_dto['test_results'].nil? || order_dto['test_results'].empty?
              mapping.update(pushed_at: Time.now)             
            else
              mapping.update(pushed_at: Time.now, result_push_status: true)  
           end
          elsif order_dto[:_id] && Lab::LimsOrderMapping.where(lims_id: order_dto[:_id]).exists?
            # HACK: v1.1.7 had a bug where duplicates of recently created orders where being created by
            # the pull worker. This here detects those duplicates and voids them.
            Rails.logger.warn("Duplicate accession number found: #{order_dto[:_id]}, skipping order...")
            fix_duplicates!(order)
          else
            Rails.logger.info("Creating order ##{order_dto[:accession_number]} in LIMS")
            update = lims_api.create_order(order_dto)
            Lab::LimsOrderMapping.create!(order: order, lims_id: update['id'], revision: update['rev'],
                                          pushed_at: Time.now, result_push_status: false)
          end
        end

        order_dto
      end

      private

      def orders_pending_sync(batch_size)
        return new_orders.limit(batch_size) if new_orders.exists?

        return voided_orders.limit(batch_size) if voided_orders.exists?

        updated_orders.limit(batch_size)
      end

      def new_orders
        Rails.logger.debug('Looking for new orders that need to be created in LIMS...')
        Lab::LabOrder.where.not(order_id: Lab::LimsOrderMapping.all.select(:order_id))
                     .order(date_created: :desc)
      end

      def updated_orders
        Rails.logger.debug('Looking for recently updated orders that need to be pushed to LIMS...')
        last_updated = Lab::LimsOrderMapping.select('MAX(updated_at) AS last_updated')
                                            .first
                                            .last_updated

        Lab::LabOrder.left_joins(:results)
                     .joins(:mapping)
                     .where('orders.discontinued_date > :last_updated
                             OR obs.date_created > orders.date_created AND lab_lims_order_mappings.result_push_status = 0',
                            last_updated: last_updated)
                     .group('orders.order_id')
                     .order(discontinued_date: :desc, date_created: :desc)
      end

      def voided_orders
        Rails.logger.debug('Looking for voided orders that are being tracked by LIMS...')
        Lab::LabOrder.unscoped
                     .where(order_type: OrderType.where(name: Lab::Metadata::ORDER_TYPE_NAME),
                            order_id: Lab::LimsOrderMapping.all.select(:order_id),
                            voided: 1)
                     .order(date_voided: :desc)
      end

      ##
      # HACK: Checks for duplicates previously created by version 1.1.7 pull worker bug due to this proving orders
      # that have not been pushed to LIMS as orders awaiting updates.
      def fix_duplicates!(order)
        return order.void('Duplicate created by bug in HIS-EMR-API-Lab v1.1.7') unless order_has_specimen?(order)

        duplicate_order = Lab::LabOrder.where(accession_number: order.accession_number)
                                       .where.not(order_id: order.order_id)
                                       .first
        return unless duplicate_order

        if !order_has_results?(order) && (order_has_results?(duplicate_order) || order_has_specimen?(duplicate_order))
          order.void('DUplicate created by bug in HIS-EMR-API-Lab v1.1.7')
        else
          duplicate_order.void('Duplicate created by bug in HIS-EMR-API-Lab v1.1.7')
          Lab::LimsOrderMapping.find_by_lims_id(order.accession_number)&.destroy
        end
      end

      def order_has_results?(order)
        order.results.exists?
      end

      def order_has_specimen?(order)
        order.concept_id == ConceptName.find_by_name!('Unknown').concept_id
      end
    end
  end
end
