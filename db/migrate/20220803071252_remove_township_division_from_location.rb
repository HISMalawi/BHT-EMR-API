class RemoveTownshipDivisionFromLocation < ActiveRecord::Migration[5.2]
  def change
    remove_column :location, :township_division, :string
  end
end
