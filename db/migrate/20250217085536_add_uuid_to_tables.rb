class AddUuidToTables < ActiveRecord::Migration[8.0]
  TABLES = %w(
    pharmacy_batch_items
    pharmacy_batches
    pharmacy_stock_balances
    pharmacy_stock_verifications
    pharmacy_obs
    drug_ingredient
    user_role
    user_property
  ).freeze

  def change
    TABLES.each do |t|
        # Add UUID column if it doesn't exist
        unless column_exists?(t, :uuid)
          add_column t, :uuid, :string, limit: 36
        end

        # Set UUID values for existing records  
        execute("UPDATE #{t} SET uuid = UUID() WHERE uuid IS NULL")

        # Make the column non-null after setting values
        change_column t, :uuid, :string, null: false, limit: 36  

        # Add unique index
        add_index t, :uuid, unique: true, length: 36
    end
  end
end
