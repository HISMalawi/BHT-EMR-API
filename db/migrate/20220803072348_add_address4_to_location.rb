class AddAddress4ToLocation < ActiveRecord::Migration[5.2]
  def change
    add_column :location, :address4, :string, null: true
  end
end
