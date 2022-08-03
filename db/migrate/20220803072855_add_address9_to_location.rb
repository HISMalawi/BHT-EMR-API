class AddAddress9ToLocation < ActiveRecord::Migration[5.2]
  def change
    add_column :location, :address9, :string
  end
end
