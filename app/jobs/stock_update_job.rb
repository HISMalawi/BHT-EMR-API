# frozen_string_literal: true

class StockUpdateJob < ApplicationJob
  queue_as :default

  def perform(json_observation)
    observation = JSON.parse(json_observation)
    date = observation['obs_datetime'].to_time
    drug_id = observation['value_drug']
    items = service.find_batch_items(drug_id: drug_id)\
                   .where('expiry_date > ?', date)
    quantity = observation['value_numeric'].to_f

    login(observation['creator'], observation['location_id'] || find_current_location)
    stock_update_strategy.call(drug_id, items, quantity, date)
  end

  private

  FEFO = 'FEFO' # First expired, first out
  FIFO = 'FIFO' # First in, first out
  LIFO = 'LIFO' # Last in, first out

  def service
    StockManagementService.new
  end

  # Returns a function that takes a list of stock items and quantity
  # then deducts the quantity as per configured strategy
  # (ie: FIFO or LIFO or FEFO).
  def stock_update_strategy
    case find_stock_update_strategy
    when FEFO
      method(:update_first_to_expire)
    when FIFO
      raise 'Not yet implemented: FIFO stock management'
    when LIFO
      raise 'Not yet implemeted: LIFO stock management'
    else
      raise "Invalid stock management strategy configured: #{configured_update_strategy}"
    end
  end

  def update_first_to_expire(drug_id, items, quantity, date)
    items.sort_by(&:expiry_date).each do |item|
      break if quantity.zero?

      item_quantity = item.current_quantity
      next if item_quantity.zero?

      if item_quantity >= quantity
        # All `quantity` can be subtracted from this single item alone.
        service.commit_transaction(item, StockManagementService::STOCK_DEBIT,
                                   -quantity, date, update_item: true)
        quantity = 0
        break
      end

      service.commit_transaction(item, StockManagementService::STOCK_DEBIT,
                                 -item_quantity, date, update_item: true)

      quantity -= item_quantity
    end

    if quantity.positive?
      Rails.logger.warn("Quantity (#{quantity}) for drug (##{drug_id}) not available in stock")
    end
  end

  def find_stock_update_strategy
    GlobalProperty.find_by(property: 'art.stock.strategy')&.property_value&.upcase || FEFO
  end

  def find_current_location
    GlobalProperty.find_by(property: 'current_health_center_id')&.property_value
  end
end
