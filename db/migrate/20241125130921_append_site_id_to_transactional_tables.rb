# frozen_string_literal: true

class AppendSiteIdToTransactionalTables < ActiveRecord::Migration[7.0]
    TRANSACTIONAL_TABLES = %w[users person_name drug_ingredient drug_order encounter orders obs patient_program
                              patient_state person_address pharmacies pharmacy_batch_items pharmacy_batches 
                              pharmacy_stock_balances pharmacy_stock_verifications relationship person_attribute
                              global_property patient person patient_identifier 
                              report_object reporting_report_design reporting_report_design_resource user_property user_role].freeze

  def up
    ActiveRecord::Base.connection.execute <<~SQL
      SET sql_mode = 'ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';
    SQL

    ActiveRecord::Base.connection.execute <<~SQL
      ALTER TABLE global_property DROP PRIMARY KEY;
    SQL

    ActiveRecord::Base.connection.execute <<~SQL
      ALTER TABLE global_property DROP INDEX global_property_uuid_index;
    SQL

    TRANSACTIONAL_TABLES.each do |t|
      add_column t.to_sym, :site_id, :integer, default: current_health_center_id unless column_exists?(t, :site_id)

      change_column t.to_sym, :site_id, :integer, default: 0 if column_exists?(t, :site_id)
    end
  end

  def current_health_center_id
    Location.current_health_center&.id
  end
end
