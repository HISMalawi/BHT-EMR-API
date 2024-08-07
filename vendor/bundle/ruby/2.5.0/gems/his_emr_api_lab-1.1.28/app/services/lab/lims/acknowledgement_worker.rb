# frozen_string_literal: true

module Lab
  module Lims
    # This class is responsible for handling the acknowledgement of lab orders
    class AcknowledgementWorker
      attr_reader :lims_api

      include Utils # for logger

      SECONDS_TO_WAIT_FOR_ORDERS = 30

      def initialize(lims_api)
        @lims_api = lims_api
      end

      def push_acknowledgement(batch_size: 1000, wait: false)
        loop do
          logger.info('Looking for new acknowledgements to push to LIMS...')
          acknowledgements = Lab::AcknowledgementService.acknowledgements_pending_sync(batch_size).all

          logger.debug("Found #{acknowledgements.size} acknowledgements...")
          acknowledgements.each do |acknowledgement|
            Lab::AcknowledgementService.push_acknowledgement(acknowledgement, @lims_api)
          rescue GatewayError => e
            logger.error("Failed to push acknowledgement ##{acknowledgement.order_id}: #{e.class} - #{e.message}")
          end

          break unless wait

          logger.info('Waiting for acknowledgements...')
          sleep(Lab::Lims::Config.updates_poll_frequency)
        end
      end
    end
  end
end
