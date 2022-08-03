class CreateCareSettings < ActiveRecord::Migration[5.2]
  def change
    create_table :care_setting, id: false do |t|
      t.primary_key :care_setting_id
      t.string :name, null: false
      t.string :description, null: true
      t.string :care_setting_type, null: false
      t.integer :creator, null: false
      t.datetime :date_created, null: false
      t.boolean :retired, null: false, default: false
      t.integer :retired_by, null: true
      t.datetime :date_retired, null: true
      t.string :retire_reason, null: true
      t.integer :changed_by, null: true
      t.datetime :date_changed, null: true
      t.string :uuid, null: false, limit: 38

      t.timestamps
    end
  end
end
