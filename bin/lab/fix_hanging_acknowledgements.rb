# frozen_string_literal: true

# fixes hanging acknowledgements whose orders have been voided

def fix_hanging_acknowledgements
  voided_orders.each do |order|
    puts "Fixing hanging acknowledgement for order #{order['order_id']}"
    acknowledgement = LimsAcknowledgementStatus.find(order['order_id'])
    acknowledgement.update!(voided: order['voided'], voided_by: order['voided_by'], date_voided: order['date_voided'], void_reason: order['void_reason'])
  end
end

def voided_orders
  ActiveRecord::Base.connection.select_all <<~SQL
    SELECT o.order_id, o.voided, o.void_reason, o.date_voided, o.voided_by
    FROM orders o
    WHERE o.voided = 1 AND o.order_id IN (#{LimsAcknowledgementStatus.all.collect(&:order_id).join(',')})
  SQL
end

Rails.logger = Logger.new($stdout)
ActiveRecord::Base.logger = Rails.logger
ActiveRecord::Base.logger.level = :debug

User.current = User.first

ActiveRecord::Base.transaction do
  fix_hanging_acknowledgements
end
