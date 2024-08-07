# frozen_string_literal: true

module Lab
  class VoidOrderJob < ApplicationJob
    queue_as :default

    def perform(order_id)
      Rails.logger.info("Voiding order ##{order_id} in LIMS")

      User.current = Lab::Lims::Utils.lab_user
      Location.current = Location.find_by_name('ART clinic')

      worker = Lab::Lims::PushWorker.new(Lab::Lims::ApiFactory.create_api)
      worker.push_order(Lab::LabOrder.unscoped.find(order_id))
    end
  end
end
