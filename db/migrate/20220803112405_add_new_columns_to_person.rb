class AddNewColumnsToPerson < ActiveRecord::Migration[5.2]
  def change
    add_column :person, :deathdate_estimated, :boolean, null: false, default: false
    add_column :person, :birthtime, :time, null: true
  end
end
