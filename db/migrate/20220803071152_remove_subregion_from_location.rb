class RemoveSubregionFromLocation < ActiveRecord::Migration[5.2]
  def change
    remove_column :location, :subregion, :string
  end
end
