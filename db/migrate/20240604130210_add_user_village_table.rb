class AddUserVillageTable < ActiveRecord::Migration[7.0]
  def change
    create_table :user_villages, primary_key: :user_village_id do |t|
      t.integer :village_id, null: false
      t.integer :user_id, null: false
      t.integer :creator, null: false
      t.integer :retired, default: 0
      t.integer :retired_by 
      t.datetime :date_retired
    end
  end
end
