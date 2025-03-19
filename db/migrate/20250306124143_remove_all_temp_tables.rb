class RemoveAllTempTables < ActiveRecord::Migration[8.0]
  def change
    art_temp_tables = %w[temp_art_start_date temp_cohort_members temp_current_medication temp_current_medication_start temp_current_state temp_current_state_start temp_earliest_start_date temp_latest_tb_status temp_maternal_status temp_max_drug_orders temp_max_drug_orders_start temp_max_patient_state temp_max_patient_state_start temp_min_auto_expire_date temp_min_auto_expire_date_start temp_order_details temp_other_patient_types temp_patient_outcomes temp_patient_outcomes_start temp_patient_side_effects temp_patient_tb_status temp_pregnant_obs temp_register_start_date tmp_max_adherence temp_tb_confirmed_and_on_treatment temp_tb_screened]

    art_temp_tables.each do |table|
      ActiveRecord::Base.connection.execute <<~SQL
        DROP TABLE IF EXISTS #{table}
      SQL
      
      print "Dropped #{table} \n"
    end
  end
end
