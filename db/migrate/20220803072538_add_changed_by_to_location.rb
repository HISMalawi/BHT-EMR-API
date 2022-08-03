class AddChangedByToLocation < ActiveRecord::Migration[5.2]
  def change
    add_column :location, :changed_by, :integer, null: true
    add_foreign_key :location, :users, column: :changed_by, primary_key: :user_id
  end
end
