# frozen_string_literal: true

class CreateLabLimsFailedImports < ActiveRecord::Migration[5.2]
  def change
    create_table :lab_lims_failed_imports do |t|
      t.string :lims_id, null: false
      t.string :tracking_number, null: false
      t.string :patient_nhid, null: false
      t.string :reason, null: false
      t.string :diff, limit: 2048

      t.timestamps

      t.index :lims_id
      t.index :patient_nhid
      t.index :tracking_number
    end
  end
end
