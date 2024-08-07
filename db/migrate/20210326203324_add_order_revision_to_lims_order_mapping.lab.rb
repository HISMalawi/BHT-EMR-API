# frozen_string_literal: true

# This migration comes from lab (originally 20210326195504)
class AddOrderRevisionToLimsOrderMapping < ActiveRecord::Migration[5.2]
  def change
    return if column_exists?(:lab_lims_order_mappings, :revision)

    add_column :lab_lims_order_mappings, :revision, :string, null: false
  end
end
