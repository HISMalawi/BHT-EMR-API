class AlterPharmacyTransaction < ActiveRecord::Migration[5.2]
  def change
    remove_column :pharmacy_obs, :expiry_date, :date
    remove_column :pharmacy_obs, :pack_size, :integer
    remove_column :pharmacy_obs, :changed_by, :integer
    remove_column :pharmacy_obs, :date_changed, :datetime
    remove_column :pharmacy_obs, :drug_id, :integer
    remove_column :pharmacy_obs, :expiring_units, :double
    remove_column :pharmacy_obs, :value_coded, :integer
    remove_column :pharmacy_obs, :value_text, :string, limit: 255
    add_column :pharmacy_obs, :transaction_reason, :text, null: true
    rename_column :pharmacy_obs, :value_numeric, :quantity

    reversible do |direction|
      direction.up do
        add_column :pharmacy_obs, :transaction_date, :date

        ActiveRecord::Base.connection.execute <<~SQL
          UPDATE pharmacy_obs SET transaction_date = DATE(encounter_date)
        SQL

        remove_column :pharmacy_obs, :encounter_date
      end

      direction.down do
        add_column :pharmacy_obs, :encounter_date, :datetime

        ActiveRecord::Base.connection.execute <<~SQL
          UPDATE pharmacy_obs SET encounter_date = transaction_date
        SQL

        remove_column :pharmacy_obs, :transaction_date
      end
    end
  end
end
