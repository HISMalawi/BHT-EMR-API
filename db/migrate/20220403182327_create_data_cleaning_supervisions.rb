# frozen_string_literal: true

class CreateDataCleaningSupervisions < ActiveRecord::Migration[5.2]
  def change
    create_table :data_cleaning_supervisions, primary_key: :data_cleaning_tool_id do |t|
      t.datetime :data_cleaning_datetime, null: false
      t.string :supervisors, null: false
      t.integer :creator, null: false
      t.boolean :voided, null: false, default: false
      t.integer :voided_by

      t.timestamps
    end
  end

  def down
    drop_table :data_cleaning_supervisions
  end
end
