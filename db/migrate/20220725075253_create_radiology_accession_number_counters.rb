# frozen_string_literal: true

# migration to create the radiology accession number table
class CreateRadiologyAccessionNumberCounters < ActiveRecord::Migration[5.2]
  def change
    create_table :radiology_accession_number_counters do |t|
      t.date :date
      t.bigint :value

      t.timestamps

      t.index :date, unique: true
    end
  end
end
