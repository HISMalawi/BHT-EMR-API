# This migration comes from lab (originally 20210310115457)
class CreateLabLimsOrderMappings < ActiveRecord::Migration[5.2]
  def change
    return if table_exists?(:lab_lims_order_mappings)

    create_table :lab_lims_order_mappings do |t|
      t.integer :lims_id, null: false, unique: true
      t.integer :order_id, null: false, unique: true
      t.datetime :pushed_at
      t.datetime :pulled_at

      t.timestamps

      t.index :lims_id
    end

    add_foreign_key :lab_lims_order_mappings, :orders, primary_key: :order_id, column: :order_id
  end
end
