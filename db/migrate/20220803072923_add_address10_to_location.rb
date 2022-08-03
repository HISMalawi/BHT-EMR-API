class AddAddress10ToLocation < ActiveRecord::Migration[5.2]
  def change
    add_column :location, :address10, :string
  end
end
