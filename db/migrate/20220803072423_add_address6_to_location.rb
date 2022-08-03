class AddAddress6ToLocation < ActiveRecord::Migration[5.2]
  def change
    add_column :location, :address6, :string, null: true
  end
end
