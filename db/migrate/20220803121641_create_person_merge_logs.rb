class CreatePersonMergeLogs < ActiveRecord::Migration[5.2]
  def change
    create_table :person_merge_log, id: false do |t|
      t.primary_key :person_merge_log_id
      t.integer :winner_person_id, null: false
      t.integer :loser_person_id, null: false
      t.integer :creator, null: false
      t.datetime :date_created, null: false
      t.text :merged_data, null: true
      t.integer :changed_by, null: true
      t.datetime :date_changed, null: true
      t.boolean :voided, null: false, default: false
      t.integer :voided_by, null: true
      t.datetime :date_voided, null: true
      t.string :void_reason, null: true
      t.string :uuid, null: false, unique: true
    end
    add_foreign_key :person_merge_log, :person, column: :winner_person_id, primary_key: :person_id
    add_foreign_key :person_merge_log, :person, column: :loser_person_id, primary_key: :person_id
    add_foreign_key :person_merge_log, :users, column: :creator, primary_key: :user_id
    add_foreign_key :person_merge_log, :users, column: :changed_by, primary_key: :user_id
    add_foreign_key :person_merge_log, :users, column: :voided_by, primary_key: :user_id
  end
end
