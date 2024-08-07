# frozen_string_literal: true

class CreateLabLabAccessionNumberCounters < ActiveRecord::Migration[5.2]
  def change
    create_table :lab_accession_number_counters do |t|
      t.date :date
      t.bigint :value

      t.timestamps

      t.index %i[date], unique: true
    end
  end
end
