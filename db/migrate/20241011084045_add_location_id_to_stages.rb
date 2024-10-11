class AddLocationIdToStages < ActiveRecord::Migration[7.0]
  def change
    add_column :stages, :location_id, :integer
  end
end
