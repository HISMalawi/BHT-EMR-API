# frozen_string_literal: true

class Openmrs19Migration < ActiveRecord::Migration[7.0]
  def change
    drop_table :stages if table_exists?(:stages)
    drop_table :visit if table_exists?(:visit)

    add_column :patient_program, :location_id, :integer unless column_exists?(:patient_program, :location_id)

    if column_exists?(:patient_program, :location_id)
      # Update NULL values to 0 (or another valid value)
      execute "UPDATE patient_program SET location_id = (
        SELECT location_id FROM location WHERE location_id = (
          SELECT property_value FROM global_property WHERE property = 'current_health_center_id' LIMIT 1
        ) LIMIT 1
      )"
      # Change the column to integer with default 0
      change_column :patient_program, :location_id, :integer if column_exists?(:patient_program, :location_id)
    end

    unless foreign_key_exists?(
      :patient_program, :location, column: :location_id
    )
      add_foreign_key :patient_program, :location, column: :location_id,
                                                   primary_key: :location_id
    end
    add_column :concept_word, :weight, :float, default: 1.0 unless column_exists?(:concept_word, :weight)
    add_column :drug, :date_changed, :datetime unless column_exists?(:drug, :date_changed)
    add_column :drug, :changed_by, :integer unless column_exists?(:drug, :changed_by)
    add_foreign_key :drug, :users, column: :changed_by, primary_key: :user_id unless foreign_key_exists?(:drug, :users,
                                                                                                         column: :changed_by)

    change_column :hl7_in_error, :error_details, :text, limit: 16.megabytes - 1 if column_exists?(:hl7_in_error,
                                                                                                  :error_details)
    change_column_null :person_name, :person_id, false if column_exists?(:person_name, :person_id)
    change_column :drug, :name, :string, limit: 255 if column_exists?(:drug, :name)
    change_column :person_address, :address1, :string, limit: 255 if column_exists?(:person_address, :address1)
    change_column :person_address, :address2, :string, limit: 255 if column_exists?(:person_address, :address2)
    change_column :person_address, :neighborhood_cell, :string, limit: 255 if column_exists?(:person_address,
                                                                                             :neighborhood_cell)
    change_column :location, :neighborhood_cell, :string, limit: 255 if column_exists?(:location, :neighborhood_cell)

    remove_column :concept, :default_charge, :decimal if column_exists?(:concept, :default_charge)

    drop_table :concept_derived if table_exists?(:concept_derived)

    unless table_exists?(:visit_type)
      create_table :visit_type, id: false, primary_key: :visit_type_id do |t|
        t.integer :visit_type_id, null: false, primary_key: true
        t.string :name, null: false
        t.string :description
        t.boolean :retired, default: false, null: false
        t.integer :retired_by
        t.datetime :date_retired
        t.string :retire_reason
        t.integer :creator, null: false
        t.datetime :date_created, null: false
        t.boolean :voided, default: false, null: false
        t.integer :voided_by
        t.datetime :date_voided
        t.string :void_reason
      end
    end

    unless table_exists?(:visit)
      create_table :visit, id: false, primary_key: :visit_id do |t|
        t.integer :visit_id, null: false, primary_key: true
        t.integer :patient_id, null: false
        t.integer :visit_type_id, null: false
        t.integer :indication_concept_id
        t.integer :location_id
        t.datetime :date_started, null: false
        t.datetime :date_stopped
        t.boolean :voided, default: false, null: false
        t.integer :voided_by
        t.datetime :date_voided
        t.string :void_reason
        t.integer :creator, null: false
        t.datetime :date_created, null: false
        t.integer :changed_by
        t.datetime :date_changed
        t.string :uuid, null: false
      end
    end

    add_foreign_key :visit, :users, column: :creator, primary_key: :user_id unless foreign_key_exists?(:visit, :users,
                                                                                                       column: :creator)
    add_foreign_key :visit, :users, column: :changed_by, primary_key: :user_id unless foreign_key_exists?(:visit,
                                                                                                          :users, column: :changed_by)
    add_foreign_key :visit, :users, column: :voided_by, primary_key: :user_id unless foreign_key_exists?(:visit,
                                                                                                         :users, column: :voided_by)
    add_foreign_key :visit, :patient, column: :patient_id, primary_key: :patient_id unless foreign_key_exists?(:visit,
                                                                                                               :patient, column: :patient_id)
    add_foreign_key :visit, :visit_type, column: :visit_type_id, primary_key: :visit_type_id unless foreign_key_exists?(
      :visit, :visit_type, column: :visit_type_id
    )
    unless foreign_key_exists?(
      :visit, :concept, column: :indication_concept_id
    )
      add_foreign_key :visit, :concept, column: :indication_concept_id,
                                        primary_key: :concept_id
    end
    add_foreign_key :visit, :location, column: :location_id, primary_key: :location_id unless foreign_key_exists?(
      :visit, :location, column: :location_id
    )

    add_column :encounter, :visit_id, :integer, null: true unless column_exists?(:encounter, :visit_id)
    add_foreign_key :encounter, :visit, column: :visit_id, primary_key: :visit_id unless foreign_key_exists?(
      :encounter, :visit, column: :visit_id
    )

    add_foreign_key :visit_type, :users, column: :creator, primary_key: :user_id unless foreign_key_exists?(
      :visit_type, :users, column: :creator
    )
    add_foreign_key :visit_type, :users, column: :voided_by, primary_key: :user_id unless foreign_key_exists?(
      :visit_type, :users, column: :voided_by
    )
    add_foreign_key :visit_type, :users, column: :retired_by, primary_key: :user_id unless foreign_key_exists?(
      :visit_type, :users, column: :retired_by
    )

    # Add indexes for performance
    add_index :visit, :patient_id unless index_exists?(:visit, :patient_id)
    add_index :visit, :location_id unless index_exists?(:visit, :location_id)
    add_index :visit, :date_started unless index_exists?(:visit, :date_started)
    add_index :visit, :date_stopped unless index_exists?(:visit, :date_stopped)
  end
end
