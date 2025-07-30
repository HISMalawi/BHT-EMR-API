# frozen_string_literal: true

# module DataCleaning
class AddColumnsToDataCleaningSupervision < ActiveRecord::Migration[7.0]
  def up
    remove_column :data_cleaning_supervisions, :created_at, :datetime
    remove_column :data_cleaning_supervisions, :updated_at, :datetime

    add_column :data_cleaning_supervisions, :comments, :text, null: true
    execute <<-SQL
      ALTER TABLE data_cleaning_supervisions ADD COLUMN date_created DATETIME NOT NULL DEFAULT NOW();
    SQL
    add_column :data_cleaning_supervisions, :changed_by, :integer, null: true
    add_column :data_cleaning_supervisions, :date_changed, :datetime, null: true
    add_column :data_cleaning_supervisions, :date_voided, :datetime, null: true
    add_column :data_cleaning_supervisions, :void_reason, :string, limit: 255, null: true
    add_column :data_cleaning_supervisions, :uuid, :string, limit: 38, null: false, unique: true

    add_foreign_key :data_cleaning_supervisions, :users, column: :changed_by, primary_key: :user_id
    add_foreign_key :data_cleaning_supervisions, :users, column: :voided_by, primary_key: :user_id
  end

  def down
    add_column :data_cleaning_supervisions, :created_at, :datetime
    add_column :data_cleaning_supervisions, :updated_at, :datetime

    remove_foreign_key :data_cleaning_supervisions, column: :changed_by, primary_key: :user_id
    remove_foreign_key :data_cleaning_supervisions, column: :voided_by, primary_key: :user_id

    remove_column :data_cleaning_supervisions, :comments, :text
    remove_column :data_cleaning_supervisions, :date_created, :datetime
    remove_column :data_cleaning_supervisions, :changed_by, :integer
    remove_column :data_cleaning_supervisions, :date_changed, :datetime
    remove_column :data_cleaning_supervisions, :date_voided, :datetime
    remove_column :data_cleaning_supervisions, :void_reason, :string
    remove_column :data_cleaning_supervisions, :uuid, :string
  end
end
