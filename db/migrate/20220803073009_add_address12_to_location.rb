class AddAddress12ToLocation < ActiveRecord::Migration[5.2]
  def change
    add_column :location, :address12, :string
  end
end
