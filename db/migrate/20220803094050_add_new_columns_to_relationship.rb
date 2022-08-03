class AddNewColumnsToRelationship < ActiveRecord::Migration[5.2]
  def change
    add_column :relationship, :start_date, :datetime, null: true
    add_column :relationship, :end_date, :datetime, null: true
    add_column :relationship, :date_changed, :datetime, null: true
    add_column :relationship, :changed_by, :integer, null: true
    add_foreign_key :relationship, :users, column: :changed_by, primary_key: :user_id
  end
end
