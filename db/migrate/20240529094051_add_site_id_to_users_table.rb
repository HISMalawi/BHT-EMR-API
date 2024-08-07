class AddSiteIdToUsersTable < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :location_id, :integer, default: nil
    
    add_foreign_key :users, :location, column: :location_id,
    primary_key: :location_id
  end
end
