class AddLocationIdToTxnTables < ActiveRecord::Migration[7.0]
  TRANSACTIONAL_TABLES = %i[users person_name drug_ingredient drug_order encounter orders obs patient_program
                            patient_state person_address pharmacies pharmacy_obs pharmacy_batch_items pharmacy_batches 
                            pharmacy_stock_balances pharmacy_stock_verifications relationship person_attribute
                            global_property patient person patient_identifier 
                            report_object reporting_report_design reporting_report_design_resource
                            user_property user_role].freeze
  def change
    id = GlobalProperty.unscoped.find_by_property('current_health_center_id')&.property_value.to_i
    Location.current = Location.find(id)

    ActiveRecord::Base.connection.execute <<~SQL
      SET sql_mode = 'ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';
    SQL
   
    TRANSACTIONAL_TABLES.each do |t|

      next if column_exists?(t, :location_id)
      
      add_column t.to_sym, :location_id, :bigint, default: id

      change_column t.to_sym, :location_id, :bigint, default: 0 if column_exists?(t, :location_id)
    end

    # check if its only one site in the DB
    sites = ActiveRecord::Base.connection.select_all <<~SQL
      SELECT DISTINCT(location_id) FROM encounter;
    SQL

    unless sites.count > 1
      TRANSACTIONAL_TABLES.each do |t|
        ActiveRecord::Base.connection.execute <<~SQL
          UPDATE #{t} SET location_id = #{id};
        SQL
      end
    end
  end

end
