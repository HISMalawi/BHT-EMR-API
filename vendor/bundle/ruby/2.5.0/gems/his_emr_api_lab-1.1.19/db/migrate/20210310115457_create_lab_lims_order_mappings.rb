class CreateLabLimsOrderMappings < ActiveRecord::Migration[5.2]
  def change
    create_table :lab_lims_order_mappings do |t|
      t.integer :lims_id, null: false, unique: true
      t.integer :order_id, null: false, unique: true
      t.datetime :pushed_at
      t.datetime :pulled_at

      t.timestamps

      t.foreign_key :orders, primary_key: :order_id, column: :order_id
      t.index :lims_id
    end
  end
end
