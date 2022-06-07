# frozen_string_literal: true

# model managing extra details for orders
class OrderExtension < ApplicationRecord
  self.table_name = :order_extension
  self.primary_key = :order_extension_id

  belongs_to :order, foreign_key: :order_id
  belongs_to :creator, class_name: 'User', foreign_key: :creator
end
