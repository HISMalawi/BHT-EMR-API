# frozen_string_literal: true

module ANCService
  # rubocop:disable Metrics/ClassLength
  # class to manage missed migrations during the first migration
  class ANCMissedMigration
    def initialize(params)
      @person_id = params[:max_person_id]
      @user_id = params[:max_user_id]
      @patient_program_id = params[:max_patient_program_id]
      @encounter_id = params[:max_encounter_id]
      @obs_id = params[:max_obs_id]
      @order_id = params[:max_order_id]
      @database = params[:database]
    end

    # rubocop:disable Metrics/MethodLength
    # this is literally java or c# in me but this method can be named anything really
    def main
      patients = central_select_all('patient_id', "#{@database}.ART_patient_in_use", '')
      return unless patients.length.positive?

      reverse_value
      patients.each do |patient|
        @patient = patient
        print_time message: "Migrating missed records for patient #{patient}"
        @anc_id = anc_patient_id patient
        migrate_program_missed patient
        migrate_encounter_missed patient
        migrate_obs_missed patient
        migrate_orders_missed patient
        print_time
      end
    end
    # rubocop:enable Metrics/MethodLength

    private

    # method to get reverse migration values
    def reverse_value
      @prev_encounter_id = central_select_one('parameter_value', "#{@database}.reverse_mapping",
                                              "WHERE parameter_name = 'max_encounter_id'")
      @prev_program_id = central_select_one('parameter_value', "#{@database}.reverse_mapping",
                                            "WHERE parameter_name = 'max_patient_program_id'")
      @prev_obs_id = central_select_one('parameter_value', "#{@database}.reverse_mapping",
                                        "WHERE parameter_name = 'max_obs_id'")
      @prev_order_id = central_select_one('parameter_value', "#{@database}.reverse_mapping",
                                          "WHERE parameter_name = 'max_order_id'")
      @prev_person_id = central_select_one('parameter_value', "#{@database}.reverse_mapping",
                                           "WHERE parameter_name = 'max_person_id'")
    end

    # migrate encounters for patients in use
    def migrate_encounter_missed(patient_id)
      anc_encounters = central_select_all('encounter_id', "#{@database}.encounter", "WHERE patient_id = #{@anc_id}")
      openmrs_encounters = central_select_all('encounter_id', 'encounter', "WHERE patient_id = '#{patient_id}'")
      not_migrated = anc_encounters.map { |value| value + @prev_encounter_id } - openmrs_encounters
      migrate_encounter(not_migrated.map { |value| value - @prev_encounter_id }) if not_migrated.length.positive?
    end

    # migrate patient program records
    def migrate_program_missed(patient_id)
      anc_program = central_select_all('patient_program_id', "#{@database}.patient_program",
                                       "WHERE patient_id = #{@anc_id}")
      openmrs_program = central_select_all('patient_program_id', 'patient_program',
                                           "WHERE patient_id = #{patient_id}")
      not_migrated = anc_program.map { |value| value + @prev_program_id } - openmrs_program
      return unless not_migrated.length.positive?

      not_migrated = not_migrated.map { |value| value - @prev_program_id }
      migrate_patient_program(not_migrated)
      migrate_patient_state(not_migrated)
    end

    # migrate obs records that were missed
    def migrate_obs_missed(patient_id)
      record = central_select_all('obs_id', "#{@database}.obs", "WHERE person_id = #{@anc_id}")
      open_record = central_select_all('obs_id', 'obs', "WHERE person_id = #{patient_id}")
      not_migrated = record.map { |value| value + @prev_obs_id } - open_record
      migrate_obs(not_migrated.map { |value| value - @prev_obs_id }) if not_migrated.length.positive?
    end

    # migrate order records that were missed
    def migrate_orders_missed(patient_id)
      record = central_select_all('order_id', "#{@database}.orders", "WHERE patient_id = #{@anc_id}")
      open_record = central_select_all('order_id', 'orders', "WHERE patient_id = #{patient_id}")
      not_migrated = record.map { |value| value + @prev_order_id } - open_record
      return unless not_migrated.length.positive?

      not_migrated = not_migrated.map { |value| value - @prev_order_id }
      migrate_orders(not_migrated)
      migrate_drug_order(not_migrated)
    end

    # method to migrate orders records
    def migrate_orders(list)
      statement = <<~SQL
        INSERT INTO orders (order_id, order_type_id, concept_id, orderer,  encounter_id,  instructions,  start_date,  auto_expire_date,  discontinued,  discontinued_date, discontinued_by,  discontinued_reason, creator, date_created,  voided,  voided_by,  date_voided,  void_reason, patient_id,  accession_number, obs_id,  uuid, discontinued_reason_non_coded)
        SELECT (SELECT #{@order_id} + order_id) AS order_id,  order_type_id, concept_id, orderer, (SELECT #{@encounter_id} + encounter_id) AS encounter_id,  instructions, start_date, auto_expire_date,  discontinued,  discontinued_date, (SELECT #{@user_id} + discontinued_by) AS discontinued_by,  discontinued_reason,  (SELECT #{@user_id} + creator) AS creator,  date_created,  voided, (SELECT #{@user_id} + voided_by) AS voided_by,  date_voided, void_reason, #{@patient}, accession_number, (SELECT #{@obs_id} + obs_id) AS obs_id, uuid, discontinued_reason_non_coded
        FROM #{@database}.orders
        WHERE order_id IN (#{list.join(',')})
      SQL
      central_hub message: 'Migrating order records', query: statement
    end

    # method to migrate drug orders records
    def migrate_drug_order(list)
      statement = <<~SQL
        INSERT INTO drug_order (order_id, drug_inventory_id, dose, equivalent_daily_dose, units, frequency, prn, complex, quantity)
        SELECT (SELECT #{@order_id} + order_id) AS order_id, drug_inventory_id, dose, equivalent_daily_dose, units, frequency, prn, complex, quantity
        FROM #{@database}.drug_order
        WHERE order_id IN (#{list.join(',')})
      SQL
      central_hub query: statement, message: 'Migrating drug_order records'
    end

    # method to migrate obs records
    def migrate_obs(list)
      statement = <<~SQL
        INSERT INTO obs (obs_id, person_id,  concept_id,  encounter_id,  order_id,  obs_datetime,  location_id,  obs_group_id,  accession_number,  value_group_id,  value_boolean,  value_coded,  value_coded_name_id,  value_drug,  value_datetime,  value_numeric,  value_modifier,  value_text,  date_started,  date_stopped,  comments,  creator,  date_created,  voided,  voided_by,  date_voided,  void_reason,  value_complex,  uuid)
        SELECT (SELECT #{@obs_id} + obs_id) AS obs_id, #{@patient},  concept_id,  (SELECT #{@encounter_id} + encounter_id) AS encounter_id,  (SELECT #{@order_id} + order_id) AS order_id, obs_datetime, location_id, (SELECT #{@obs_id} + obs_group_id) AS obs_group_id, accession_number, value_group_id, value_boolean, value_coded, value_coded_name_id, value_drug, value_datetime, value_numeric, value_modifier, value_text, date_started, date_stopped,  comments, (SELECT #{@user_id} + creator) AS creator, date_created, voided, (SELECT #{@user_id} + voided_by) AS voided_by, date_voided, void_reason, value_complex,  uuid
        FROM #{@database}.obs
        WHERE obs_id IN (#{list.join(',')})
      SQL
      central_hub message: 'Migrating obs records:', query: statement
    end

    # method to migrate patient program records
    def migrate_patient_program(list)
      statement = <<~SQL
        INSERT INTO patient_program (patient_program_id,  patient_id,  program_id,  date_enrolled,  date_completed,  creator,  date_created, changed_by,  date_changed,  voided, voided_by,  date_voided,  void_reason,  uuid,  location_id)
        SELECT (SELECT #{@patient_program_id} + patient_program_id) AS patient_program_id,  #{@patient},  program_id,  date_enrolled,  date_completed,  (SELECT #{@user_id} + creator) AS creator,  date_created, (SELECT #{@user_id} + changed_by) AS changed_by, date_changed,  voided,  (SELECT #{@user_id} + voided_by) AS voided_by,  date_voided,  void_reason,  uuid, location_id
        FROM #{@database}.patient_program
        WHERE patient_program_id IN (#{list.join(',')})
      SQL
      central_hub message: 'Migrating patient_program records', query: statement
    end

    # method to migrate patient state records
    def migrate_patient_state(list)
      statement = <<~SQL
        INSERT INTO patient_state (patient_program_id, state, start_date, end_date, creator, date_created, changed_by, date_changed, voided, voided_by, date_voided, void_reason, uuid)
        SELECT (SELECT #{@patient_program_id} + patient_program_id) AS patient_program_id, state, start_date, end_date, (SELECT #{@user_id} + creator) AS creator, date_created,  (SELECT #{@user_id} + changed_by) AS changed_by, date_changed, voided,  (SELECT #{@user_id} + voided_by) AS voided_by, date_voided, void_reason, uuid
        FROM #{@database}.patient_state
        WHERE patient_program_id IN (#{list.join(',')})
      SQL
      central_hub message: 'Migrating patient_state records', query: statement
    end

    # method to migrate encounter records
    def migrate_encounter(list)
      statement = <<~SQL
        INSERT INTO encounter (encounter_id, encounter_type, patient_id, provider_id, location_id, form_id, encounter_datetime, creator, date_created, voided, voided_by, date_voided, void_reason, uuid, changed_by, date_changed, program_id)
        SELECT (SELECT #{@encounter_id} + encounter_id) AS id, encounter_type, #{@patient}, (SELECT #{@prev_person_id} + provider_id) AS provider_id, location_id, form_id, encounter_datetime, (SELECT #{@user_id} + creator) AS creator, date_created, voided, (SELECT #{@user_id} + voided_by) AS voided_by, date_voided, void_reason, uuid, (SELECT #{@user_id} + changed_by) AS changed_by, date_changed, 12
        FROM #{@database}.encounter
        WHERE encounter_id in (#{list.join(',')})
      SQL
      central_hub message: 'Migrating encounter records', query: statement
    end

    # method to get anc patient id
    def anc_patient_id(patient_id)
      result = ActiveRecord::Base.connection.select_one <<~SQL
        SELECT anc_patient_id FROM #{@database}.patient_migration_mapping where art_patient_id = #{patient_id} LIMIT 1
      SQL
      result['anc_patient_id']
    end

    # central select one hub
    def central_select_one(field, table_name, condition)
      result = ActiveRecord::Base.connection.select_one <<~SQL
        SELECT #{field} FROM #{table_name} #{condition}
      SQL
      result[field.to_s]
    end

    # central place to select an array of records
    def central_select_all(field, table_name, condition)
      result = ActiveRecord::Base.connection.select_all <<~SQL
        SELECT #{field} FROM #{table_name} #{condition}
      SQL
      result.map { |variable| variable[field.to_s].to_i }
    end

    # central place to execute mysql commands
    def central_hub(message: nil, query: nil)
      print_time message: message if message
      ActiveRecord::Base.connection.execute query
      print_time if message
    end

    # method to print time when running some heavy things
    def print_time(message: 'Done', long_form: false)
      puts "#{message}: #{long_form ? Time.now : Time.now.strftime('%H:%M:%S')}"
    end
  end
  # rubocop:enable Metrics/ClassLength
end
