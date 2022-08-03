class AddAddress7ToLocation < ActiveRecord::Migration[5.2]
  def change
    add_column :location, :address7, :string
  end
end
