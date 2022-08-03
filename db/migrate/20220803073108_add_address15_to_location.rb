class AddAddress15ToLocation < ActiveRecord::Migration[5.2]
  def change
    add_column :location, :address15, :string
  end
end
