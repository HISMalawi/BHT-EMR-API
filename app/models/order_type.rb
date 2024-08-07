# frozen_string_literal: true

class OrderType < RetirableRecord
  self.table_name = :order_type
  self.primary_key = :order_type_id

  has_many :orders
end
