class AddNewColumnsToPatientIdentifier < ActiveRecord::Migration[5.2]
  def change
    add_column :patient_identifier, :date_changed, :datetime, null: true
    add_column :patient_identifier, :changed_by, :integer, null: true
    add_foreign_key :patient_identifier, :users, column: :changed_by, primary_key: :user_id
  end
end
