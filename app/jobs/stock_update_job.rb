# frozen_string_literal: true

class StockUpdateJob < ApplicationJob
  queue_as :default

  def perform(mode, user_id, location_id, json_observation)
    login(user_id, location_id)

    observation = JSON.parse(json_observation)
    date = observation['obs_datetime'].to_datetime
    drug_id = observation['value_drug']
    quantity = observation['value_numeric'].to_f

    amount_rejected = service.update_batch_items(mode, drug_id, quantity, date)

    return unless amount_rejected.positive?

    logger.warn("#{amount_rejected} left from #{mode} stock operation")
  end

  private

  def service
    StockManagementService.new
  end
end
