# frozen_string_literal: true

class CreatePharmacyStockVerifications < ActiveRecord::Migration[5.2]
  def change
    create_table :pharmacy_stock_verifications do |t|
      t.string :reason
      t.datetime :verification_date
      t.integer :creator
      t.datetime :date_created
      t.integer :changed_by
      t.datetime :date_changed
      t.boolean :voided
      t.integer :voided_by
      t.string :void_reason
      t.datetime :date_voided

      t.timestamps
    end
  end
end
