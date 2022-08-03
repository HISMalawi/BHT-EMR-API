class AddNewColumnsToPersonAddress < ActiveRecord::Migration[5.2]
  def change
    add_column :person_address, :date_changed, :datetime, null: true
    add_column :person_address, :changed_by, :integer, null: true
    add_column :person_address, :start_date, :datetime, null: true
    add_column :person_address, :end_date, :datetime, null: true
    add_column :person_address, :address3, :string, null: true
    add_column :person_address, :address4, :string, null: true
    add_column :person_address, :address5, :string, null: true
    add_column :person_address, :address6, :string, null: true
    add_column :person_address, :address7, :string, null: true
    add_column :person_address, :address8, :string, null: true
    add_column :person_address, :address9, :string, null: true
    add_column :person_address, :address10, :string, null: true
    add_column :person_address, :address11, :string, null: true
    add_column :person_address, :address12, :string, null: true
    add_column :person_address, :address13, :string, null: true
    add_column :person_address, :address14, :string, null: true
    add_column :person_address, :address15, :string, null: true

    add_foreign_key :person_address, :users, column: :changed_by, primary_key: :user_id
  end
end
