# rubocop:disable Metrics/MethodLength
# frozen_string_literal: true

def orders
  ActiveRecord::Base.connection.select_all <<~SQL
    SELECT do.order_id
    FROM drug_order do
        INNER JOIN drug d ON do.drug_inventory_id = d.drug_id
        INNER JOIN orders o ON do.order_id = o.order_id
        INNER JOIN encounter e ON o.encounter_id = e.encounter_id
    WHERE e.program_id = 12
        AND d.name = 'SP (3 tablets)'
        AND do.quantity = 0
    GROUP BY do.order_id
  SQL
end

def give_them_three_tabs(order)
  DrugOrder.find(order['order_id']).update(quantity: 3)
end

puts "Found #{orders.length} orders with dispensed SP (3 tablets) of 0 quantity, cleaning data..."

start = Time.now

ActiveRecord::Base.transaction do
  orders.each(&method(:give_them_three_tabs))
end

puts "Done in #{Time.now - start} seconds"

# rubocop:enable Metrics/MethodLength
