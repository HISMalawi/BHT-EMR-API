class AddLocationIdToVisits < ActiveRecord::Migration[7.0]
  def change
    add_column :visits, :location_id, :integer
  end
end
