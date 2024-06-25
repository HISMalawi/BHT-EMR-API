# frozen_string_literal: true

module Lab
  ##
  # Push an order to LIMS.
  class PushOrderJob < ApplicationJob
    def perform(order_id)
      push_worker = Lab::Lims::PushWorker.new(Lab::Lims::ApiFactory.create_api)
      push_worker.push_order_by_id(order_id)
    end
  end
end
