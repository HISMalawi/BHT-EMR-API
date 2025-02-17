class AddUuidToTables < ActiveRecord::Migration[8.0]
  TABLES = %w(
    pharmacy_batch_items
    pharmacy_batches
    pharmacy_stock_balances
    pharmacy_stock_verifications
    pharmacy_obs
    drug_ingredient
  )

  def change
    TABLES.each do |t|
      add_column t.to_sym, :uuid, :string, limit: 36, if_not_exists: true

      # populate uuid for existing records
      execute <<-SQL
        UPDATE #{t} SET uuid = UUID() WHERE uuid IS NULL;
      SQL

      # alter column to not allow null
      change_column t.to_sym, :uuid, false, if_exists: true
    end
  end
end
