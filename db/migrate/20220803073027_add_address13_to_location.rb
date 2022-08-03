class AddAddress13ToLocation < ActiveRecord::Migration[5.2]
  def change
    add_column :location, :address13, :string
  end
end
