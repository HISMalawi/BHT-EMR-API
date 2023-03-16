# frozen_string_literal: true

require 'csv'

RADIOLOGY_EXAMINATION = EncounterType.find_by_name!('RADIOLOGY EXAMINATION')
RADIOLOGY_PROGRAM = Program.find_by_name!('RADIOLOGY PROGRAM')

@obs_collections = []

def save_changed_obs
  CSV.open("log/orphaned_obs_reassigned_#{Time.now.strftime('%Y_%m_%d_%H_%M_%S')}.csv", 'w') do |csv|
    csv << %w[obs_id order_id]
    @obs_collections.each do |obs|
      csv << obs
    end
  end
end

def all_encounters
  Encounter.where(type: RADIOLOGY_EXAMINATION, program: RADIOLOGY_PROGRAM)
end

def all_orders
  Order.where(encounter: all_encounters)
end

def process_orphaned_obs(order)
  return unless Observation.where(order: order).empty?

  obs = order.encounter.observations.where('obs_datetime <= ? AND order_id IS NULL', order.date_created)
  obs.each do |ob|
    ob.order_id = order.id
    ob.save!
    @obs_collections << [ob.id, order.id]
  end
end

def process_all_orphaned_obs
  all_orders.each do |order|
    process_orphaned_obs(order)
  end
end

Rails.logger = Logger.new($stdout)
ActiveRecord::Base.logger = Rails.logger
ActiveRecord::Base.logger.level = :debug

start_time = Time.now
ActiveRecord::Base.transaction do
  process_all_orphaned_obs
  save_changed_obs
  Rails.logger.info('Successfully processed')
end
end_time = Time.now

Rails.logger.info("Finished in #{end_time - start_time} seconds")
