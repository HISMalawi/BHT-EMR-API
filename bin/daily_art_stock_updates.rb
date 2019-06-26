# frozen_string_literal: true

require 'logger'

include ModelUtils

LOGGER = Logger.new(STDOUT)
ActiveRecord::Base.logger = LOGGER

def main(date = Date.today)
  process_debits(date)
  process_credits(date)
end

def process_debits(date)
  LOGGER.debug('Processing ART stock debits (dispensations)')
  dispensations(date).each do |dispensation|
    login_as(dispensation.creator, at: dispensation.location_id)
    stock_service.update_batch_items(StockManagementService::STOCK_DEBIT,
                                     dispensation.value_drug,
                                     dispensation.value_numeric,
                                     dispensation.obs_datetime.to_date)
  end
end

# Credits are simply just voids
def process_credits(date)
  LOGGER.debug('Processing ART stock credits (voided dispensations)')
  voided_dispensations(date).each do |dispensation|
    next if dispensation.date_voided.to_date == dispensation.date_created.to_date

    login_as(dispensation.creator, at: dispensation.location_id)
    stock_service.update_batch_items(StockManagementService::STOCK_ADD,
                                     dispensation.value_drug,
                                     dispensation.value_numeric,
                                     dispensation.obs_datetime.to_date)
  end
end

def dispensations(date)
  start_time, end_time = TimeUtils.day_bounds(date)
  Observation.where('concept_id = ? AND obs_datetime BETWEEN ? AND ?',
                    concept_name_to_id('Amount dispensed'),
                    start_time,
                    end_time)
end

def voided_dispensations(date)
  start_time, end_time = TimeUtils.day_bounds(date)
  Observation.unscoped\
             .where('concept_id = ? AND date_voided BETWEEN ? AND ?',
                    concept_name_to_id('Amount dispensed'),
                    start_time,
                    end_time)
end

def stock_service
  StockManagementService.new
end

def login_as(user_id, at: nil)
  at ||= current_location_id

  User.current = User.find(user_id)
  Location.current = Location.find(at)
end

def current_location_id
  value = global_property('current_health_center_id')&.property_value
  raise 'Global property `current_health_center_id` not set' unless value

  value
end

main
