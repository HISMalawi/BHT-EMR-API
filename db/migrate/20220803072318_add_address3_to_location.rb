class AddAddress3ToLocation < ActiveRecord::Migration[5.2]
  def change
    add_column :location, :address3, :string, null: true
  end
end
