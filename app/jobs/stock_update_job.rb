# frozen_string_literal: true

class StockUpdateJob < ApplicationJob
  queue_as :default

  def perform(action, user_id:, location_id:, dispensation_id:)
    login(user_id, location_id)

    amount_rejected = update_stock(action, dispensation_id)
    logger.warn("#{amount_rejected} left from #{action} stock operation") if amount_rejected.positive?
  end

  private

  def update_stock(action, dispensation_id)
    case action
    when 'process_dispensation'
      service.process_dispensation(dispensation_id)
    when 'reverse_dispensation'
      service.reverse_dispensation(dispensation_id)
    else
      raise "Invalid stock update action: #{action}"
    end
  end

  def service
    StockManagementService.new
  end
end
