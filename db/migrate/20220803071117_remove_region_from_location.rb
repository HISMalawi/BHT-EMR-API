class RemoveRegionFromLocation < ActiveRecord::Migration[5.2]
  def change
    remove_column :location, :region, :string
  end
end
