class AddDateChangedToLocation < ActiveRecord::Migration[5.2]
  def change
    add_column :location, :date_changed, :datetime, null: true
  end
end
