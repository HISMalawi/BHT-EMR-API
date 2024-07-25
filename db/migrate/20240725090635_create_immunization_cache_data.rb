class CreateImmunizationCacheData < ActiveRecord::Migration[7.0]
  def change
    create_table :immunization_cache_data, id: false, primary_key: :name do |t|
      t.string :name, null:false
      t.json :value, null: false
      t.timestamps
    end
  end
end
