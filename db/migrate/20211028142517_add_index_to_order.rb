# frozen_string_literal: true

class AddIndexToOrder < ActiveRecord::Migration[5.2]
  def change
    return if ActiveRecord::Base.connection.index_exists?(:orders, %i[patient_id order_id])

    add_index :orders, %i[patient_id order_id], name: 'order_id_patient_id_temp'
  end
end
