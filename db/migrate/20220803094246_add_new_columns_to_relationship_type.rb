class AddNewColumnsToRelationshipType < ActiveRecord::Migration[5.2]
  def change
    add_column :relationship_type, :date_changed, :datetime, null: true
    add_column :relationship_type, :changed_by, :integer, null: true
    add_foreign_key :relationship_type, :users, column: :changed_by, primary_key: :user_id
  end
end
