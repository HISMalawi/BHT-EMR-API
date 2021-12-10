# frozen_string_literal: true

module ANCService
  # rubocop:disable Metrics/ClassLength
  # Class managing the migration of anc data to
  class ANCMigration
    def initialize(params)
      @person_id = params[:person_id]
      @user_id = params[:user_id]
      @patient_program_id = params[:patient_program_id]
      @encounter_id = params[:encounter_id]
      @obs_id = params[:obs_id]
      @order_id = params[:order_id]
      @database = params[:database]
    end

    # rubocop:disable Metrics/MethodLength
    # rubocop:disable Metrics/AbcSize
    # main method to do the workflow
    def main
      puts "Started at #{Time.now}"
      create_user_bak
      ActiveRecord::Base.transaction do
        ActiveRecord::Base.connection.disable_referential_integrity do
          migrate_users
          migrate_person
        end
        migrate_person_name
        migrate_person_address
        migrate_person_attribute
        migrate_patient
        migrate_patient_identifier
        migrate_patient_program
        migrate_patient_state
        migrate_encounter
        migrate_obs
        migrate_orders
        migrate_drug_order
      end
      create_migration_residuals
      puts "Ended at #{Time.now}"
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/MethodLength

    private

    # method to create user mapping
    def create_user_bak
      ActiveRecord::Base.connection.execute <<~SQL
        DROP TABLE IF EXISTS #{@database}.user_bak
      SQL

      ActiveRecord::Base.connection.execute <<~SQL
        CREATE TABLE #{@database}.user_bak as
        SELECT user_id AS ANC_user_id, (SELECT #{@user_id} + user_id) AS ART_user_id, (SELECT #{@person_id} + person_id) AS person_id FROM #{@database}.users
      SQL

      ActiveRecord::Base.connection.execute <<~SQL
        ALTER TABLE #{@database}.user_bak ADD PRIMARY KEY (ANC_user_id)
      SQL
    end

    # method to migrate users records
    def migrate_users
      puts "Migrating user records: #{Time.now.strftime('%H:%M:%S')}"
      ActiveRecord::Base.connection.execute <<~SQL
        UPDATE #{@database}.users SET username = CONCAT(username, '_anc')
        WHERE username NOT LIKE '%_anc%'
      SQL

      ActiveRecord::Base.connection.execute <<~SQL
        INSERT INTO users (user_id,  system_id,  username,  password,  salt,  secret_question,  secret_answer,  creator,  date_created,  changed_by,  date_changed,  person_id,  retired,  retired_by,  date_retired,  retire_reason,  uuid,  authentication_token)
        SELECT (SELECT #{@user_id} + user_id) AS user_id, system_id,  username,  password,  salt,  secret_question,  secret_answer, (SELECT #{@user_id} + creator) AS creator,  date_created,  (SELECT #{@user_id} + changed_by) AS changed_by,  date_changed, (SELECT #{@person_id} + person_id),  retired, (SELECT #{@user_id} + retired_by) AS retired_by,  date_retired,  retire_reason,  uuid,  authentication_token FROM #{@database}.users
      SQL
      puts "Finished migrating users: #{Time.now.strftime('%H:%M:%S')}"
    end

    # method to migrate person records
    def migrate_person
      puts "Migrating person records: #{Time.now.strftime('%H:%M:%S')}"
      ActiveRecord::Base.connection.execute <<~SQL
        INSERT INTO person (person_id, gender, birthdate, birthdate_estimated, dead, death_date, cause_of_death, creator, date_created, changed_by, date_changed, voided, voided_by, date_voided, void_reason, uuid)
        SELECT (SELECT #{@person_id} + person_id) AS person_id, gender, birthdate, birthdate_estimated, dead, death_date, cause_of_death, (SELECT #{@user_id} + creator) AS creator, date_created, (SELECT #{@user_id} + changed_by) AS changed_by, date_changed, voided, (SELECT #{@user_id} + voided_by) AS voided_by, date_voided, void_reason, uuid  FROM #{@database}.person
      SQL
      puts "Finished migrating person: #{Time.now.strftime('%H:%M:%S')}"
    end

    # method to migrate person name records
    def migrate_person_name
      puts "Migrating person name records: #{Time.now.strftime('%H:%M:%S')}"
      ActiveRecord::Base.connection.execute <<~SQL
        INSERT INTO person_name (preferred, person_id, prefix, given_name, middle_name, family_name_prefix, family_name, family_name2, family_name_suffix, degree, creator, date_created, voided, voided_by, date_voided, void_reason, changed_by, date_changed, uuid)
        SELECT preferred, (SELECT #{@person_id} + person_id) AS person_id, prefix, given_name, middle_name, family_name_prefix, family_name, family_name2, family_name_suffix, degree, (SELECT #{@user_id} + creator) AS creator, date_created, voided, (SELECT #{@user_id} + voided_by) AS voided_by, date_voided, void_reason, (SELECT #{@user_id} + changed_by) AS changed_by, date_changed, uuid
        FROM #{@database}.person_name
      SQL
      puts "Finished migrating person_name: #{Time.now.strftime('%H:%M:%S')}"
    end

    # method to migrate person address records
    def migrate_person_address
      puts "Migrating person address records: #{Time.now.strftime('%H:%M:%S')}"
      ActiveRecord::Base.connection.execute <<~SQL
        INSERT INTO person_address (person_id,  preferred,  address1,  address2,  city_village,  state_province,  postal_code,  country,  latitude,  longitude,  creator,  date_created,  voided,  voided_by,  date_voided, void_reason, county_district,  neighborhood_cell,  region,  subregion,  township_division,  uuid)
        SELECT (SELECT #{@person_id} + p.person_id) AS person_id, p.preferred,  p.address1,  p.address2,  p.city_village,  p.state_province, p.postal_code,  p.country,  p.latitude,  p.longitude,  (SELECT #{@user_id} + p.creator) AS creator,  p.date_created,  p.voided,  (SELECT #{@user_id} + p.voided_by) AS voided_by, p.date_voided, p.void_reason, p.county_district,  p.neighborhood_cell,  p.region,  p.subregion,  p.township_division, uuid
        FROM #{@database}.person_address p
      SQL
      puts "Finished migrating person_address: #{Time.now.strftime('%H:%M:%S')}"
    end

    # method to migrate person attribute records
    def migrate_person_attribute
      puts "Migrating person attribute records: #{Time.now.strftime('%H:%M:%S')}"
      ActiveRecord::Base.connection.execute <<~SQL
        INSERT INTO person_attribute (person_id, value, person_attribute_type_id, creator, date_created, changed_by, date_changed, voided, voided_by, date_voided, void_reason, uuid)
        SELECT (SELECT #{@person_id} + p.person_id) AS person_id, p.value, p.person_attribute_type_id, (SELECT #{@user_id} + p.creator) AS creator, p.date_created,  (SELECT #{@user_id} + p.changed_by) AS changed_by, p.date_changed, p.voided,  p.voided_by, p.date_voided, p.void_reason, uuid
        FROM #{@database}.person_attribute p
      SQL
      puts "Finished person_attribute: #{Time.now.strftime('%H:%M:%S')}"
    end

    # method to migrate patient records
    def migrate_patient
      puts "Migrating patient records: #{Time.now.strftime('%H:%M:%S')}"
      ActiveRecord::Base.connection.execute <<~SQL
        INSERT INTO patient (patient_id, tribe, creator, date_created, changed_by, date_changed, voided, voided_by, date_voided, void_reason)
        SELECT (SELECT #{@person_id} + p.patient_id) AS patient_id, p.tribe, (SELECT #{@user_id} + p.creator) AS creator, p.date_created,  (SELECT #{@user_id} + p.changed_by) AS changed_by, p.date_changed, p.voided, (SELECT #{@user_id} + p.voided_by) AS voided_by, p.date_voided, p.void_reason
        FROM #{@database}.patient p
      SQL
      puts "Finished patient: #{Time.now.strftime('%H:%M:%S')}"
    end

    # method to migrate patient identifier records
    def migrate_patient_identifier
      puts "Migrating patient identifier records: #{Time.now.strftime('%H:%M:%S')}"
      ActiveRecord::Base.connection.execute <<~SQL
        INSERT INTO patient_identifier (patient_id,  identifier,  identifier_type,  preferred,  location_id,  creator,  date_created,  voided,  voided_by,  date_voided,  void_reason,  uuid)
        SELECT (SELECT #{@person_id} + p.patient_id) AS patient_id, p.identifier, p.identifier_type,  p.preferred,  p.location_id,  (SELECT #{@user_id} + p.creator) AS creator,  p.date_created,  p.voided, (SELECT #{@user_id} + p.voided_by) AS voided_by, p.date_voided, p.void_reason, uuid
        FROM #{@database}.patient_identifier p
      SQL
      puts "Finished patient_identifier: #{Time.now.strftime('%H:%M:%S')}"
    end

    # method to migrate patient program records
    def migrate_patient_program
      puts "Migrating patient program records: #{Time.now.strftime('%H:%M:%S')}"
      ActiveRecord::Base.connection.execute <<~SQL
        INSERT INTO patient_program (patient_program_id,  patient_id,  program_id,  date_enrolled,  date_completed,  creator,  date_created, changed_by,  date_changed,  voided, voided_by,  date_voided,  void_reason,  uuid,  location_id)
        SELECT (SELECT #{@patient_program_id} + patient_program_id) AS patient_program_id,  (SELECT #{@person_id} + patient_id) AS patient_id,  program_id,  date_enrolled,  date_completed,  (SELECT #{@user_id} + creator) AS creator,  date_created, (SELECT #{@user_id} + changed_by) AS changed_by, date_changed,  voided,  (SELECT #{@user_id} + voided_by) AS voided_by,  date_voided,  void_reason,  uuid, location_id
        FROM #{@database}.patient_program
      SQL
      puts "Finished patient_program: #{Time.now.strftime('%H:%M:%S')}"
    end

    # method to migrate patient state records
    def migrate_patient_state
      puts "Migrating patient state records: #{Time.now.strftime('%H:%M:%S')}"
      ActiveRecord::Base.connection.execute <<~SQL
        INSERT INTO patient_state (patient_program_id, state, start_date, end_date, creator, date_created, changed_by, date_changed, voided, voided_by, date_voided, void_reason, uuid)
        SELECT (SELECT #{@patient_program_id} + patient_program_id) AS patient_program_id, state, start_date, end_date, (SELECT #{@user_id} + creator) AS creator, date_created,  (SELECT #{@user_id} + changed_by) AS changed_by, date_changed, voided,  (SELECT #{@user_id} + voided_by) AS voided_by, date_voided, void_reason, uuid
        FROM #{@database}.patient_state
        WHERE patient_program_id IN (SELECT patient_program_id FROM #{@database}.patient_program)
      SQL
      puts "Finished patient_state: #{Time.now.strftime('%H:%M:%S')}"
    end

    # method to migrate encounter records
    def migrate_encounter
      puts "Migrating encounter records: #{Time.now.strftime('%H:%M:%S')}"
      ActiveRecord::Base.connection.execute <<~SQL
        INSERT INTO encounter (encounter_id, encounter_type, patient_id, provider_id, location_id, form_id, encounter_datetime, creator, date_created, voided, voided_by, date_voided, void_reason, uuid, changed_by, date_changed, program_id)
        SELECT (SELECT #{@encounter_id} + encounter_id) AS id, encounter_type, (SELECT #{@person_id} + patient_id) AS patient_id, (SELECT #{@person_id} + provider_id) AS provider_id, location_id, form_id, encounter_datetime, (SELECT #{@user_id} + creator) AS creator, date_created, voided, (SELECT #{@user_id} + voided_by) AS voided_by, date_voided, void_reason, uuid, (SELECT #{@user_id} + changed_by) AS changed_by, date_changed, 12
        FROM #{@database}.encounter;
      SQL
      puts "Finished encounter: #{Time.now.strftime('%H:%M:%S')}"
    end

    # method to migrate obs records
    def migrate_obs
      puts "Migrating obs records: #{Time.now.strftime('%H:%M:%S')}"
      ActiveRecord::Base.connection.execute <<~SQL
        INSERT INTO obs (obs_id, person_id,  concept_id,  encounter_id,  order_id,  obs_datetime,  location_id,  obs_group_id,  accession_number,  value_group_id,  value_boolean,  value_coded,  value_coded_name_id,  value_drug,  value_datetime,  value_numeric,  value_modifier,  value_text,  date_started,  date_stopped,  comments,  creator,  date_created,  voided,  voided_by,  date_voided,  void_reason,  value_complex,  uuid)
        SELECT (SELECT #{@obs_id} + obs_id) AS obs_id, (SELECT #{@person_id} + person_id) AS person_id,  concept_id,  (SELECT #{@encounter_id} + encounter_id) AS encounter_id,  (SELECT #{@order_id} + order_id) AS order_id, obs_datetime, location_id, (SELECT #{@obs_id} + obs_group_id) AS obs_group_id, accession_number, value_group_id, value_boolean, value_coded, value_coded_name_id, value_drug, value_datetime, value_numeric, value_modifier, value_text, date_started, date_stopped,  comments, (SELECT #{@user_id} + creator) AS creator, date_created, voided, (SELECT #{@user_id} + voided_by) AS voided_by, date_voided, void_reason, value_complex,  uuid
        FROM #{@database}.obs
        WHERE encounter_id IN (SELECT encounter_id FROM #{@database}.encounter)
      SQL
      puts "Finished obs: #{Time.now.strftime('%H:%M:%S')}"
    end

    # method to migrate orders records
    def migrate_orders
      puts "Migrating order records: #{Time.now.strftime('%H:%M:%S')}"
      ActiveRecord::Base.connection.execute <<~SQL
        INSERT INTO orders (order_id, order_type_id, concept_id, orderer,  encounter_id,  instructions,  start_date,  auto_expire_date,  discontinued,  discontinued_date, discontinued_by,  discontinued_reason, creator, date_created,  voided,  voided_by,  date_voided,  void_reason, patient_id,  accession_number, obs_id,  uuid, discontinued_reason_non_coded)
        SELECT (SELECT #{@order_id} + order_id) AS order_id,  order_type_id, concept_id, orderer, (SELECT #{@encounter_id} + encounter_id) AS encounter_id,  instructions, start_date, auto_expire_date,  discontinued,  discontinued_date, (SELECT #{@user_id} + discontinued_by) AS discontinued_by,  discontinued_reason,  (SELECT #{@user_id} + creator) AS creator,  date_created,  voided, (SELECT #{@user_id} + voided_by) AS voided_by,  date_voided, void_reason, (SELECT #{@person_id} + patient_id) AS patient_id, accession_number, (SELECT #{@obs_id} + obs_id) AS obs_id, uuid, discontinued_reason_non_coded
        FROM #{@database}.orders
        WHERE encounter_id IN (SELECT encounter_id FROM #{@database}.encounter)
      SQL
      puts "Finished orders: #{Time.now.strftime('%H:%M:%S')}"
    end

    # method to migrate drug orders records
    def migrate_drug_order
      puts "Migrating drug_order records: #{Time.now.strftime('%H:%M:%S')}"
      ActiveRecord::Base.connection.execute <<~SQL
        INSERT INTO drug_order (order_id, drug_inventory_id, dose, equivalent_daily_dose, units, frequency, prn, complex, quantity)
        SELECT (SELECT #{@order_id} + order_id) AS order_id, drug_inventory_id, dose, equivalent_daily_dose, units, frequency, prn, complex, quantity
        FROM #{@database}.drug_order
        WHERE order_id IN (SELECT order_id FROM #{@database}.orders)
      SQL
      puts "Finished drug_order: #{Time.now.strftime('%H:%M:%S')}"
    end

    # rubocop:disable Metrics/MethodLength
    # method to create migration residuals so that there can be a trace of how data was migrated
    def create_migration_residuals
      ActiveRecord::Base.connection.execute <<~SQL
        DROP TABLE IF EXISTS #{@database}.migration_mapping
      SQL

      ActiveRecord::Base.connection.execute <<~SQL
        CREATE TABLE #{@database}.migration_mapping(
          parameter_name varchar(50) NOT NULL,
          parameter_value INT NOT NULL,
          primary key (parameter_name)
        )
      SQL

      ActiveRecord::Base.connection.execute <<~SQL
        INSERT INTO #{@database}.migration_mapping(parameter_name, parameter_value)
        VALUES ('max_person_id', '#{@person_id}'),('max_user_id', '#{@user_id}'),
        ('max_patient_program_id', '#{@patient_program_id}'),('max_encounter_id', '#{@encounter_id}'),
        ('max_obs_id', '#{@obs_id}'),('max_order_id', '#{@order_id}')
      SQL
    end
    # rubocop:enable Metrics/MethodLength
  end
  # rubocop:enable Metrics/ClassLength
end
