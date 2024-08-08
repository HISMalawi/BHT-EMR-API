class AddLocationIdToImmunizationCache < ActiveRecord::Migration[7.0]
  def change
    # Remove the index on the `name` column if it exists
    remove_index :immunization_cache_data, :name if index_exists?(:immunization_cache_data, :name)

    # Add a new column for location_id
    add_column :immunization_cache_data, :location_id, :integer, default: nil

    # Add a new primary key column named `id` (auto-incrementing by default)
    add_column :immunization_cache_data, :id, :primary_key
  end
end
