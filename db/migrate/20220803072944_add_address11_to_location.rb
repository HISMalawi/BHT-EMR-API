class AddAddress11ToLocation < ActiveRecord::Migration[5.2]
  def change
    add_column :location, :address11, :string
  end
end
