class AddNewColumnsToOrderType < ActiveRecord::Migration[5.2]
  def change
    add_column :order_type, :java_class_name, :string, null: true
    add_column :order_type, :parent, :integer, null: true
    add_column :order_type, :changed_by, :integer, null: true
    add_column :order_type, :date_changed, :datetime, null: true

    add_foreign_key :order_type, :users, column: :changed_by, primary_key: :user_id
    add_foreign_key :order_type, :order_type, column: :parent, primary_key: :order_type_id
  end
end
