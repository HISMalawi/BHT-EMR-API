class AddAddress14ToLocation < ActiveRecord::Migration[5.2]
  def change
    add_column :location, :address14, :string
  end
end
