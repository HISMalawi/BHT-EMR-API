class CreateImmunizationCacheData < ActiveRecord::Migration[7.0]
  def change
    result = ActiveRecord::Base.connection.select_one "SHOW VARIABLES WHERE variable_name = 'version'"
    unless result['Value'].include?('5.6')
      create_table :immunization_cache_data, id: false, primary_key: :name do |t|
        t.string :name, null:false
        t.json :value, null: false
        t.timestamps
      end
    end
  end
end
