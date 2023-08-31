# frozen_string_literal: true

# This is the migration file that will create the table that will hold the stock card report
class CreatePharmacyStockBalances < ActiveRecord::Migration[5.2]
  def change
    create_table :pharmacy_stock_balances do |t|
      t.references :drug, null: false
      t.integer :pack_size, null: false
      t.float :open_balance, default: 0
      t.float :close_balance, default: 0
      t.date :transaction_date, null: false

      t.timestamps
    end
  end
end
