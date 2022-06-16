# frozen_string_literal: true

# model managing extra details for orders
class OrderExtension < ApplicationRecord
  include Voidable
  self.table_name = :order_extension
  self.primary_key = :order_extension_id

  default_scope { where(voided: 0) }
  scope :voided, -> { unscoped.where.not(voided: 0) }

  belongs_to :order, foreign_key: :order_id
  belongs_to :creator, class_name: 'User', foreign_key: :creator
end
