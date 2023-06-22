# frozen_string_literal: true

# This script migrates statuses from local nlims to the EMR
# It is meant to be run on the EMR

def nlims_statuses
  ActiveRecord::Base.connection.select_all <<~SQL
    SELECT ra.tracking_number, tr.result, ra.result_date, ts.name status, t.updated_at status_time
    FROM #{@lims_db}.results_acknwoledges ra
    INNER JOIN #{@lims_db}.test_results tr ON tr.test_id = ra.test_id
    INNER JOIN #{@lims_db}.tests t ON t.id = ra.test_id
    INNER JOIN #{@lims_db}.test_statuses ts ON ts.id = t.test_status_id
  SQL
end

def update_order_status(nlims_data)
  Lab::OrdersService.update_order_status(nlims_data)
end

def find_order(tracking_number)
  Order.find_by_accession_number(tracking_number)
end

def update_order_result_date(order, result_date)
  # first check if we have an observation that belongs to this order
  # and then update the obs_value_datetime
  obs = Observation.where(order_id: order.id, concept_id: ConceptName.find_by_name('Lab test result').concept_id)&.first
  return unless obs

  obs.update!(value_datetime: result_date)
end

# get the lab_daemon user
User.current = User.find_by_username('lab_daemon')

# ask the user for the database name
puts 'Enter the name of the database to migrate statuses from'
@lims_db = gets.chomp

# start a database transaction
ActiveRecord::Base.transaction do
  # get the statuses from the nlims
  nlims_statuses.each do |nlims_status|
    order = find_order(nlims_status['tracking_number'])
    next unless order

    puts "Migrating status for #{nlims_status['tracking_number']}"
    # update the order status
    update_order_status(nlims_status)

    # update the order result date
    update_order_result_date(order, nlims_status['result_date'])
  end
end
