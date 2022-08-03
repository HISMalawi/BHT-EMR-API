class RemoveLocationTypeIdFromLocation < ActiveRecord::Migration[5.2]
  def change
    remove_column :location, :location_type_id, :string
  end
end
