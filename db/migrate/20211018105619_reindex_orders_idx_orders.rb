# frozen_string_literal: true

class ReindexOrdersIdxOrders < ActiveRecord::Migration[5.2]
  def change
    if index_exists?(:orders, %i[start_date patient_id concept_id order_type_id], name: 'idx_order')
      remove_index(:orders, name: 'idx_order')
    end

    add_index(:orders, %i[order_type_id concept_id patient_id start_date], name: 'idx_order')
    add_index(:orders, %i[order_type_id auto_expire_date], name: 'idx_order_expiry')
    add_index(:order_type, :name) unless index_exists?(:order_type, :name)
  end
end
