class AddNewColumnsToPatientIdentifierType < ActiveRecord::Migration[5.2]
  def change
    add_column :patient_identifier_type, :location_behavior, :string, null: true
    add_column :patient_identifier_type, :uniqueness_behavior, :string, null: true
    add_column :patient_identifier_type, :date_changed, :datetime, null: true
    add_column :patient_identifier_type, :changed_by, :integer, null: true
    add_foreign_key :patient_identifier_type, :users, column: :changed_by, primary_key: :user_id
  end
end
