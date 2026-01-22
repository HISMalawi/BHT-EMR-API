# frozen_string_literal: true

# This migration comes from lab (originally 20260119104240)
# This migration adds fields to the orders table to support the comment to fulfiller feature.
class AddFulfillerFieldsToOrders < ActiveRecord::Migration[5.2]
  def change
    add_column :orders, :comment_to_fulfiller, :string, limit: 1024 unless column_exists?(:orders,
                                                                                          :comment_to_fulfiller)
    add_column :orders, :fulfiller_comment, :string, limit: 1024 unless column_exists?(:orders, :fulfiller_comment)
    add_column :orders, :fulfiller_status, :string, limit: 50 unless column_exists?(:orders, :fulfiller_status)
  end
end
