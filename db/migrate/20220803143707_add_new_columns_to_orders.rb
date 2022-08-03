class AddNewColumnsToOrders < ActiveRecord::Migration[5.2]
  def change
    add_column :orders, :date_stopped, :datetime, null: true
    add_column :orders, :order_reason, :integer, null: true
    add_column :orders, :order_reason_non_coded, :string, null: true
    add_column :orders, :urgency, :string, null: true
    add_column :orders, :order_number, :string, null: true
    add_column :orders, :previous_order_id, :integer, null: true
    add_column :orders, :order_action, :string, null: true
    add_column :orders, :comment_to_fulfiller, :string, null: true
    add_column :orders, :care_setting, :bigint, null: true
    add_column :orders, :scheduled_date, :datetime, null: true
    add_column :orders, :order_group_id, :integer, null: true
    add_column :orders, :sort_weight, :decimal, precision: 10, scale: 2, null: true

    add_foreign_key :orders, :concept, column: :order_reason, primary_key: :concept_id
    add_foreign_key :orders, :orders, column: :previous_order_id, primary_key: :order_id
    add_foreign_key :orders, :orders, column: :order_group_id, primary_key: :order_id
    add_foreign_key :orders, :care_setting, column: :care_setting, primary_key: :care_setting_id
  end
end
