class AddAddress5ToLocation < ActiveRecord::Migration[5.2]
  def change
    add_column :location, :address5, :string, null: true
  end
end
