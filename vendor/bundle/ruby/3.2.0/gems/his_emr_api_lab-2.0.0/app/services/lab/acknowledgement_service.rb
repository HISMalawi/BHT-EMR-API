# frozen_string_literal: true

module Lab
  # acknoledgement service for creating lab acknowledgements
  module AcknowledgementService
    class << self
      def create_acknowledgement(params)
        order = Order.find(params[:order_id])
        Lab::LabAcknowledgement.create!(order_id: order.id, test: params[:test], pushed: false,
                                        acknowledgement_type: params[:entered_by] == 'LIMS' ? 'test_results_delivered_to_site_electronically' : 'test_results_delivered_to_site_manually',
                                        date_received: params[:date_received])
      end

      def acknowledgements_pending_sync(batch_size)
        Lab::LabAcknowledgement.where(pushed: false)
                               .limit(batch_size)
      end

      def push_acknowledgement(acknowledgement, lims_api)
        Rails.logger.info("Pushing acknowledgement ##{acknowledgement.order_id}")

        acknowledgement_dto = Lab::Lims::AcknowledgementSerializer.serialize_acknowledgement(acknowledgement)
        mapping = Lab::LimsOrderMapping.find_by(order_id: acknowledgement.order_id)

        ActiveRecord::Base.transaction do
          if mapping
            Rails.logger.info("Updating acknowledgement ##{acknowledgement_dto[:tracking_number]} in LIMS")
            response = lims_api.acknowledge(acknowledgement_dto)
            Rails.logger.info("Info #{response}")
            if response['status'] == 200 || response['message'] == 'results already delivered for test name given'
              acknowledgement.pushed = true
              acknowledgement.date_pushed = Time.now
              acknowledgement.save!
            else
              Rails.logger.error("Failed to process acknowledgement for tracking number ##{acknowledgement_dto[:tracking_number]} in LIMS")
            end
          else
            Rails.logger.info("No mapping found for acknowledgement ##{acknowledgement_dto[:tracking_number]}")
          end
        end
      end
    end
  end
end
