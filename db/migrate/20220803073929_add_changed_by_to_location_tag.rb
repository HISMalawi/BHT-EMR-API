class AddChangedByToLocationTag < ActiveRecord::Migration[5.2]
  def change
    add_column :location_tag, :changed_by, :integer, null: true
    add_column :location_tag, :date_changed, :datetime, null: true
    add_foreign_key :location_tag, :users, column: :changed_by, primary_key: :user_id
  end
end
