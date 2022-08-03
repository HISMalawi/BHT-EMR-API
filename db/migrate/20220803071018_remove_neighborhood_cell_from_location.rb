class RemoveNeighborhoodCellFromLocation < ActiveRecord::Migration[5.2]
  def change
    remove_column :location, :neighborhood_cell, :string
  end
end
