class AddAddress8ToLocation < ActiveRecord::Migration[5.2]
  def change
    add_column :location, :address8, :string
  end
end
