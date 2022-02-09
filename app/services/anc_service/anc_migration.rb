# frozen_string_literal: true

module ANCService
  # rubocop:disable Metrics/ClassLength
  # Class managing the migration of anc data to
  class ANCMigration
    include ActionView::Helpers::DateHelper
    def initialize(database)
      @person_id = max_person_id
      @user_id = max_user_id
      @patient_program_id = max_patient_program_id
      @encounter_id = max_encounter_id
      @obs_id = max_obs_id
      @order_id = max_order_id
      @database = database
    end

    # rubocop:disable Metrics/MethodLength
    # rubocop:disable Metrics/AbcSize
    # main method to do the workflow
    def main
      start_time = Time.now
      @backup = check_user_bak?
      @database_reversed = check_patient_in_use?
      if @backup
        if @database_reversed
          @user_id = check_migration_map? ? user_id_from_map : user_id_from_bak
          @patient_not_in_use = patient_not_in_use
          abnormal
        else
          puts 'Migration already happened you might want to reverse first before running this.'
          return
        end
      else
        normal
      end
      puts "Migration took #{time_ago_in_words(Time.now - (Time.now - start_time), include_seconds: true)}"
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/MethodLength

    private

    # quick method to check whether all anc patients are in openmrs_kawale
    def fetch_patients_not_in_openmrs
      fetch_anc_patients.to_a - fetch_art_patients.to_a
    end

    # fetch patients in openmrs
    def fetch_patients_in_openmrs
      fetch_anc_patients.to_a - fetch_patients_not_in_openmrs
    end

    # method to fetch anc patients
    def fetch_anc_patients
      ActiveRecord::Base.connection.select_all <<~SQL
        SELECT person_name.given_name, person_name.family_name, patient_identifier.identifier FROM #{@database}.person_name
        INNER JOIN #{@database}.patient_identifier ON patient_identifier.patient_id = person_name.person_id
        WHERE person_name.voided = 0
        AND patient_identifier.identifier_type = 3
        AND patient_identifier.voided = 0
      SQL
    end

    # method to fetch art/openmrs patients
    def fetch_art_patients
      ActiveRecord::Base.connection.select_all <<~SQL
        SELECT person_name.given_name, person_name.family_name, patient_identifier.identifier FROM person_name
        INNER JOIN patient_identifier ON patient_identifier.patient_id = person_name.person_id
        WHERE person_name.voided = 0
        AND patient_identifier.identifier_type = 3
        AND patient_identifier.voided = 0
      SQL
    end

    # rubocop:disable Metrics/MethodLength
    # rubocop:disable Metrics/AbcSize
    # method to execute normal migration
    def normal
      print_time message: 'Starting a normal migration', long_form: true
      create_user_bak
      ActiveRecord::Base.transaction do
        ActiveRecord::Base.connection.disable_referential_integrity do
          migrate_users
          migrate_person(fetch_user_person_id, 'Migratating user specific person records')
          migrate_person_name(fetch_user_person_id, 'Migrating system users name records')
        end
        migrate_person()
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
        update_migrated_records
      end
      create_migration_residuals
      print_time message: 'Normal migratrion finished', long_form: true
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/MethodLength

    # method to get users person ids
    def fetch_user_person_id
      result = ActiveRecord::Base.connection.select_all <<~SQL
        SELECT person_id FROM #{@database}.users
      SQL
      result.map { |person| person['person'] }.push(0).join(',')
    end

    # method to fetch linked patients
    def fetch_mapped_patients
      statement = <<~SQL
        SELECT anc_patient_id, art_patient_id FROM mapped_patients
        #{'WHERE anc_patient_id NOT IN (SELECT anc)'}
      SQL
    end

    # rubocop:disable Metrics/MethodLength
    # rubocop:disable Metrics/AbcSize
    # method to execute a migration after a reversal was done
    def abnormal
      print_time message: 'Starting an abnormal migration (KAWALE CASE)', long_form: true
      begin
        ActiveRecord::Base.transaction do
          update_openmrs_users
          migrate_person
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
          ANCService::ANCMissedMigration.new({ max_person_id: @person_id,
                                               max_user_id: @user_id, max_patient_program_id: @patient_program_id,
                                               max_encounter_id: @encounter_id, max_obs_id: @obs_id,
                                               max_order_id: @order_id, database: @database }).main

          update_migrated_records
        end
        create_migration_residuals
        remove_holding_tables
      rescue StandardError => e
        puts e.message[0..1000]
      end
      print_time message: 'Abnormal migratrion finished', long_form: true
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/MethodLength

    # rubocop:disable Metrics/MethodLength
    # method to create user mapping
    def create_user_bak
      statement = <<~SQL
        DROP TABLE IF EXISTS #{@database}.user_bak
      SQL
      central_hub query: statement
      statement = <<~SQL
        CREATE TABLE #{@database}.user_bak as
        SELECT user_id AS ANC_user_id, (SELECT #{@user_id} + user_id) AS ART_user_id, (SELECT #{@person_id} + person_id) AS person_id FROM #{@database}.users
      SQL
      central_hub message: 'Creating use backup', query: statement
      statement = <<~SQL
        ALTER TABLE #{@database}.user_bak ADD PRIMARY KEY (ANC_user_id)
      SQL
      central_hub query: statement
    end
    # rubocop:enable Metrics/MethodLength

    # method to update openmrs_users that match those in anc database
    def update_openmrs_users
      statement = <<~SQL
        UPDATE users SET username = CONCAT(username, '_anc')
        WHERE user_id IN (SELECT ART_user_id FROM #{@database}.user_bak)
        AND username NOT LIKE '%_anc%'
      SQL
      central_hub message: 'Updating usernames', query: statement
    end

    # method to migrate users records
    def migrate_users
      statement = <<~SQL
        INSERT INTO users (user_id,  system_id,  username,  password,  salt,  secret_question,  secret_answer,  creator,  date_created,  changed_by,  date_changed,  person_id,  retired,  retired_by,  date_retired,  retire_reason,  uuid,  authentication_token)
        SELECT (SELECT #{@user_id} + user_id) AS user_id, system_id,  CONCAT(username, '_anc'),  password,  salt,  secret_question,  secret_answer, (SELECT #{@user_id} + creator) AS creator,  date_created,  (SELECT #{@user_id} + changed_by) AS changed_by,  date_changed, (SELECT #{@person_id} + person_id),  retired, (SELECT #{@user_id} + retired_by) AS retired_by,  date_retired,  retire_reason,  uuid,  authentication_token FROM #{@database}.users
      SQL
      central_hub message: 'Migrating users records', query: statement
    end

    # method to loop and create linkage between anc and openmrs(art) database
    def map_linkage_between_anc_and_openmrs
      print_time message: 'Mapping Patients'
      create_mapped
      create_unmapped
      anc = ActiveRecord::Base.connection.select_all <<~SQL
        select identifier, patient_id
        from  #{@database}.patient_identifier
        where patient_identifier.identifier_type = 3
        and patient_identifier.voided = 0
      SQL

      anc.each do |identifier|
        openmrs = PatientIdentifier.where(identifier: identifier['identifier'].to_s)
        result = check_match(identifier['patient_id'], openmrs)
        result.blank? ? unmapped_patients(identifier['patient_id'], identifier['identifier']) : mapped_patients(result, identifier['identifier'])
      end
      print_time
    end

    # method to check dob
    def check_match(anc, openmrs)
      record = nil
      openmrs.each do |identifier|
        @score = 0
        ANCDetails.fetch_dob(@database, anc) == identifier.patient.person.birthdate ? @score += 10 : nil
        anc_name = ANCDetails.fetch_name(@database, anc)
        anc_name['given_name'] == identifier.patient.person.names[0].given_name ? @score += 10 : nil
        anc_name['family_name'] == identifier.patient.person.names[0].family_name ? @score += 10 : nil
        ANCDetails.fetch_gender(@database, anc) == identifier.patient.person.gender ? @score += 10 : nil
        check_address(ANCDetails.fetch_address(@data, anc), identifier.patient.person.addresses[0])
        check_attribute(anc, identifier)
        record = { anc => identifier.patitent.id } if @score >= 50
        break if @score >= 50
      end
      record
    end

    # method to check person attributes
    def check_attribute(anc, openmrs)
      @score += 10 if attribute_checker(anc, openmrs, 13)
      @score += 10 if attribute_checker(anc, openmrs, 12)
      @score += 6.25 if attribute_checker(anc, openmrs, 3)
    end

    # method to just check the different attribute types of a patient
    def attribute_checker(anc, openmrs, type)
      record = ANCDetails.fetch_attribute(@database, anc, type)
      return false if record.blank?

      record == openmrs.patient.person.person_attributes.find_by(person_attribute_type_id: type)&.value
    end

    # method to check addresses
    def check_address(anc, openmrs)
      @score += 6.25 if anc['address2'] == openmrs['address2']
      @score += 6.25 if anc['county_district'] == openmrs['county_district']
      @score += 6.25 if anc['neighborhood_cell'] == openmrs['neighborhood_cell']
      @score += 6.25 if anc['state_province'] == openmrs['state_province']
      @score += 6.25 if anc['city_village'] == openmrs['city_village']
      @score += 6.25 if anc['address1'] == openmrs['address1']
    end

    # method to create unmapped table
    def create_mapped
      statements = <<~SQL
        DROP TABLE IF EXISTS #{@database}.mapped_patients;
        CREATE TABLE #{@database}.mapped_patients (anc_patient_id int NOT NULL, art_patient_id int NOT NULL,identifier varchar(255) NOT NULL,PRIMARY KEY (anc_patient_id))
      SQL
      print_time message: 'Creating a table of patients with linkage'
      statements.split(';').each { |value| central_hub message: nil, query: value.strip }
      print_time
    end

    # method saved mapped patients
    def mapped_patients(map, identifier)
      statement = <<~SQL
        INSERT INTO #{@database}.mapped_patients(anc_patient_id, art_patient_id, identifier)
        VALUES (#{map.keys[0]}, #{map.values[0]}, #{identifier})
      SQL
      central_execute statement
    end

    # method to create unmapped table
    def create_unmapped
      statements = <<~SQL
        DROP TABLE IF EXISTS #{@database}.unmapped_patients;
        CREATE TABLE #{@database}.unmapped_patients (anc_patient_id int NOT NULL,identifier varchar(255) NOT NULL,PRIMARY KEY (anc_patient_id))
      SQL
      print_time message: 'Creating a table of patients without any linkage'
      statements.split(';').each { |value| central_hub message: nil, query: value.strip }
      print_time
    end

    # method to save patients without any linkage
    def unmapped_patients(patient_id, identifier)
      statement = <<~SQL
        INSERT INTO #{@database}.unmapped_patients(anc_patient_id, identifier)
        VALUES (#{patient_id}, #{identifier})
      SQL
      central_execute statement
    end

    # method to migrate person records
    def migrate_person(patients, msg)
      statement = <<~SQL
        INSERT INTO person (person_id, gender, birthdate, birthdate_estimated, dead, death_date, cause_of_death, creator, date_created, changed_by, date_changed, voided, voided_by, date_voided, void_reason, uuid)
        SELECT (SELECT #{@person_id} + person_id) AS person_id, gender, birthdate, birthdate_estimated, dead, death_date, cause_of_death, (SELECT #{@user_id} + creator) AS creator, date_created, (SELECT #{@user_id} + changed_by) AS changed_by, date_changed, voided, (SELECT #{@user_id} + voided_by) AS voided_by, date_voided, void_reason, uuid
        FROM #{@database}.person
        WHERE person_id IN (#{patients})
      SQL
      central_hub message: msg, query: statement
    end

    # method to migrate person name records
    def migrate_person_name(patients, msg)
      statement = <<~SQL
        INSERT INTO person_name (preferred, person_id, prefix, given_name, middle_name, family_name_prefix, family_name, family_name2, family_name_suffix, degree, creator, date_created, voided, voided_by, date_voided, void_reason, changed_by, date_changed, uuid)
        SELECT preferred, (SELECT #{@person_id} + person_id) AS person_id, prefix, given_name, middle_name, family_name_prefix, family_name, family_name2, family_name_suffix, degree, (SELECT #{@user_id} + creator) AS creator, date_created, voided, (SELECT #{@user_id} + voided_by) AS voided_by, date_voided, void_reason, (SELECT #{@user_id} + changed_by) AS changed_by, date_changed, uuid
        FROM #{@database}.person_name
        WHERE person_id IN (#{patients})
      SQL
      central_hub message: msg, query: statement
    end

    # method to migrate person address records
    def migrate_person_address(patients, msg)
      statement = <<~SQL
        INSERT INTO person_address (person_id,  preferred,  address1,  address2,  city_village,  state_province,  postal_code,  country,  latitude,  longitude,  creator,  date_created,  voided,  voided_by,  date_voided, void_reason, county_district,  neighborhood_cell,  region,  subregion,  township_division,  uuid)
        SELECT (SELECT #{@person_id} + p.person_id) AS person_id, p.preferred,  p.address1,  p.address2,  p.city_village,  p.state_province, p.postal_code,  p.country,  p.latitude,  p.longitude,  (SELECT #{@user_id} + p.creator) AS creator,  p.date_created,  p.voided,  (SELECT #{@user_id} + p.voided_by) AS voided_by, p.date_voided, p.void_reason, p.county_district,  p.neighborhood_cell,  p.region,  p.subregion,  p.township_division, uuid
        FROM #{@database}.person_address p
        WHERE p.person_id IN (#{patients})
      SQL
      central_hub message: msg, query: statement
    end

    # method to migrate person attribute records
    def migrate_person_attribute(patients, msg)
      statement = <<~SQL
        INSERT INTO person_attribute (person_id, value, person_attribute_type_id, creator, date_created, changed_by, date_changed, voided, voided_by, date_voided, void_reason, uuid)
        SELECT (SELECT #{@person_id} + p.person_id) AS person_id, p.value, p.person_attribute_type_id, (SELECT #{@user_id} + p.creator) AS creator, p.date_created,  (SELECT #{@user_id} + p.changed_by) AS changed_by, p.date_changed, p.voided,  p.voided_by, p.date_voided, p.void_reason, uuid
        FROM #{@database}.person_attribute p
        WHERE p.person_id IN (#{patients})
      SQL
      central_hub message: msg, query: statement
    end

    # method to migrate patient records
    def migrate_patient(patients, msg)
      statement = <<~SQL
        INSERT INTO patient (patient_id, tribe, creator, date_created, changed_by, date_changed, voided, voided_by, date_voided, void_reason)
        SELECT (SELECT #{@person_id} + p.patient_id) AS patient_id, p.tribe, (SELECT #{@user_id} + p.creator) AS creator, p.date_created,  (SELECT #{@user_id} + p.changed_by) AS changed_by, p.date_changed, p.voided, (SELECT #{@user_id} + p.voided_by) AS voided_by, p.date_voided, p.void_reason
        FROM #{@database}.patient p
        WHERE p.patient_id IN (#{patients})
      SQL
      central_hub message: msg, query: statement
    end

    # method to migrate patient identifier records
    def migrate_patient_identifier(patients, msg)
      statement = <<~SQL
        INSERT INTO patient_identifier (patient_id,  identifier,  identifier_type,  preferred,  location_id,  creator,  date_created,  voided,  voided_by,  date_voided,  void_reason,  uuid)
        SELECT (SELECT #{@person_id} + p.patient_id) AS patient_id, p.identifier, p.identifier_type,  p.preferred,  p.location_id,  (SELECT #{@user_id} + p.creator) AS creator,  p.date_created,  p.voided, (SELECT #{@user_id} + p.voided_by) AS voided_by, p.date_voided, p.void_reason, uuid
        FROM #{@database}.patient_identifier p
        WHERE p.patient_id IN (#{patients})
      SQL
      central_hub message: msg, query: statement
    end

    # method to migrate patient program records
    def migrate_patient_program(patients, msg)
      statement = <<~SQL
        INSERT INTO patient_program (patient_program_id,  patient_id,  program_id,  date_enrolled,  date_completed,  creator,  date_created, changed_by,  date_changed,  voided, voided_by,  date_voided,  void_reason,  uuid,  location_id)
        SELECT (SELECT #{@patient_program_id} + patient_program_id) AS patient_program_id,  (SELECT #{@person_id} + patient_id) AS patient_id,  program_id,  date_enrolled,  date_completed,  (SELECT #{@user_id} + creator) AS creator,  date_created, (SELECT #{@user_id} + changed_by) AS changed_by, date_changed,  voided,  (SELECT #{@user_id} + voided_by) AS voided_by,  date_voided,  void_reason,  uuid, location_id
        FROM #{@database}.patient_program
        WHERE patient_id IN (#{patients})
      SQL
      central_hub message: msg, query: statement
    end

    # method to migrate patient state records
    def migrate_patient_state(patients, msg)
      statement = <<~SQL
        INSERT INTO patient_state (patient_program_id, state, start_date, end_date, creator, date_created, changed_by, date_changed, voided, voided_by, date_voided, void_reason, uuid)
        SELECT (SELECT #{@patient_program_id} + patient_program_id) AS patient_program_id, state, start_date, end_date, (SELECT #{@user_id} + creator) AS creator, date_created,  (SELECT #{@user_id} + changed_by) AS changed_by, date_changed, voided,  (SELECT #{@user_id} + voided_by) AS voided_by, date_voided, void_reason, uuid
        FROM #{@database}.patient_state
        WHERE patient_program_id IN (SELECT patient_program_id FROM #{@database}.patient_program WHERE patient_id IN (#{patients}))
      SQL
      central_hub message: msg, query: statement
    end

    # method to migrate encounter records
    def migrate_encounter
      # statement = <<~SQL
      #   INSERT INTO encounter (encounter_id, encounter_type, patient_id, provider_id, location_id, form_id, encounter_datetime, creator, date_created, voided, voided_by, date_voided, void_reason, uuid, changed_by, date_changed, program_id)
      #   SELECT (SELECT #{@encounter_id} + encounter_id) AS id, encounter_type, (SELECT #{@person_id} + patient_id) AS patient_id, (SELECT #{@person_id} + provider_id) AS provider_id, location_id, form_id, encounter_datetime, (SELECT #{@user_id} + creator) AS creator, date_created, voided, (SELECT #{@user_id} + voided_by) AS voided_by, date_voided, void_reason, uuid, (SELECT #{@user_id} + changed_by) AS changed_by, date_changed, 12
      #   FROM #{@database}.encounter
      # SQL
      # central_hub message: 'Migrating encounter records', query: statement
      migrate_encounter_system_users
      migrate_encounter_not_system_users
    end

    # method to load previous person id
    def prev_person_id
      result = ActiveRecord::Base.connection.select_one <<~SQL
        SELECT parameter_value FROM #{@database}.reverse_mapping WHERE parameter_name = 'max_person_id'
      SQL
      result['parameter_value'].to_i
    end

    # method to migrate encounter whose providers are system users
    def migrate_encounter_system_users(patients, msg)
      statement = <<~SQL
        INSERT INTO encounter (encounter_id, encounter_type, patient_id, provider_id, location_id, form_id, encounter_datetime, creator, date_created, voided, voided_by, date_voided, void_reason, uuid, changed_by, date_changed, program_id)
        SELECT (SELECT #{@encounter_id} + encounter_id) AS id, encounter_type, (SELECT #{@person_id} + patient_id) AS patient_id, (SELECT #{prev_person_id} + provider_id) AS provider_id, location_id, form_id, encounter_datetime, (SELECT #{@user_id} + creator) AS creator, date_created, voided, (SELECT #{@user_id} + voided_by) AS voided_by, date_voided, void_reason, uuid, (SELECT #{@user_id} + changed_by) AS changed_by, date_changed, 12
        FROM #{@database}.encounter
        WHERE provider_id IN (SELECT person_id FROM #{@database}.users) AND patient_id IN (#{patients})
      SQL
      central_hub message: msg, query: statement
    end

    # method to migrate encounter whose providers are system users
    def migrate_encounter_not_system_users(patients, msg)
      statement = <<~SQL
        INSERT INTO encounter (encounter_id, encounter_type, patient_id, provider_id, location_id, form_id, encounter_datetime, creator, date_created, voided, voided_by, date_voided, void_reason, uuid, changed_by, date_changed, program_id)
        SELECT (SELECT #{@encounter_id} + e.encounter_id) AS id, e.encounter_type, (SELECT #{@person_id} + e.patient_id) AS patient_id, bak.person_id AS provider_id, e.location_id, e.form_id, e.encounter_datetime, bak.ART_user_id AS creator, e.date_created, e.voided, (SELECT #{@user_id} + e.voided_by) AS voided_by, e.date_voided, e.void_reason, e.uuid, (SELECT #{@user_id} + e.changed_by) AS changed_by, e.date_changed, 12
        FROM #{@database}.encounter e
        INNER JOIN #{@database}.user_bak bak ON e.creator = bak.ANC_user_id
        WHERE provider_id NOT IN (SELECT person_id FROM #{@database}.users) AND patient_id IN (#{patients})
      SQL
      central_hub message: msg, query: statement
    end

    # method to migrate obs records
    def migrate_obs(patients, msg)
      statement = <<~SQL
        INSERT INTO obs (obs_id, person_id,  concept_id,  encounter_id,  order_id,  obs_datetime,  location_id,  obs_group_id,  accession_number,  value_group_id,  value_boolean,  value_coded,  value_coded_name_id,  value_drug,  value_datetime,  value_numeric,  value_modifier,  value_text,  date_started,  date_stopped,  comments,  creator,  date_created,  voided,  voided_by,  date_voided,  void_reason,  value_complex,  uuid)
        SELECT (SELECT #{@obs_id} + obs_id) AS obs_id, (SELECT #{@person_id} + person_id) AS person_id,  concept_id,  (SELECT #{@encounter_id} + encounter_id) AS encounter_id,  (SELECT #{@order_id} + order_id) AS order_id, obs_datetime, location_id, (SELECT #{@obs_id} + obs_group_id) AS obs_group_id, accession_number, value_group_id, value_boolean, value_coded, value_coded_name_id, value_drug, value_datetime, value_numeric, value_modifier, value_text, date_started, date_stopped,  comments, (SELECT #{@user_id} + creator) AS creator, date_created, voided, (SELECT #{@user_id} + voided_by) AS voided_by, date_voided, void_reason, value_complex,  uuid
        FROM #{@database}.obs
        WHERE encounter_id IN (SELECT encounter_id FROM #{@database}.encounter WHERE patient_id IN (#{patients}))
      SQL
      central_hub message: msg, query: statement
    end

    # method to migrate orders records
    def migrate_orders(patients, msg)
      statement = <<~SQL
        INSERT INTO orders (order_id, order_type_id, concept_id, orderer,  encounter_id,  instructions,  start_date,  auto_expire_date,  discontinued,  discontinued_date, discontinued_by,  discontinued_reason, creator, date_created,  voided,  voided_by,  date_voided,  void_reason, patient_id,  accession_number, obs_id,  uuid, discontinued_reason_non_coded)
        SELECT (SELECT #{@order_id} + order_id) AS order_id,  order_type_id, concept_id, orderer, (SELECT #{@encounter_id} + encounter_id) AS encounter_id,  instructions, start_date, auto_expire_date,  discontinued,  discontinued_date, (SELECT #{@user_id} + discontinued_by) AS discontinued_by,  discontinued_reason,  (SELECT #{@user_id} + creator) AS creator,  date_created,  voided, (SELECT #{@user_id} + voided_by) AS voided_by,  date_voided, void_reason, (SELECT #{@person_id} + patient_id) AS patient_id, accession_number, (SELECT #{@obs_id} + obs_id) AS obs_id, uuid, discontinued_reason_non_coded
        FROM #{@database}.orders
        WHERE encounter_id IN (SELECT encounter_id FROM #{@database}.encounter WHERE patient_id IN (#{patients}) )
      SQL
      central_hub message: msg, query: statement
    end

    # method to migrate drug orders records
    def migrate_drug_order(patients, msg)
      statement = <<~SQL
        INSERT INTO drug_order (order_id, drug_inventory_id, dose, equivalent_daily_dose, units, frequency, prn, complex, quantity)
        SELECT (SELECT #{@order_id} + order_id) AS order_id, drug_inventory_id, dose, equivalent_daily_dose, units, frequency, prn, complex, quantity
        FROM #{@database}.drug_order
        WHERE order_id IN (SELECT order_id FROM #{@database}.orders WHERE patient_id IN (#{patients}))
      SQL
      central_hub query: statement, message: msg
    end

    # rubocop:disable Metrics/MethodLength
    # method to update migated records
    def update_migrated_records
      statements = <<~SQL
        UPDATE encounter set encounter_type = 98 where encounter_type = 61;
        UPDATE obs SET value_text = null, value_coded = 1065, value_coded_name_id = 1102 WHERE concept_id = 2723 and value_text IN ('Given during previous ANC visit for current pregnancy', 'Given Today', 'Yes');
        UPDATE obs SET value_text = null, value_coded = 1066, value_coded_name_id = 1103 WHERE concept_id = 2723 and value_text IN ('No', 'Not given today or during current pregnancy');
        UPDATE #{@database}.obs SET value_text = null, value_coded = 1067, value_coded_name_id = 1104 WHERE concept_id = 2723 and value_text IN ('Unknown');
        UPDATE obs SET value_text = null, value_coded = 1065, value_coded_name_id = 1102 WHERE value_text = 'Yes';
        UPDATE obs SET value_text = null, value_coded = 1066, value_coded_name_id = 1103 WHERE value_text = 'No';
        UPDATE obs SET value_text = null, value_coded = 1067, value_coded_name_id = 1104 WHERE value_text = 'Unknown';
        UPDATE obs SET value_text = null, value_coded = 703, value_coded_name_id = 718 WHERE value_text = 'Positive';
        UPDATE obs SET value_text = null, value_coded = 664, value_coded_name_id = 678 WHERE value_text = 'Negative';
        UPDATE obs SET value_text = null, value_coded = 2475, value_coded_name_id = 5944 WHERE value_text = 'Not Done';
        UPDATE obs SET value_text = null, value_coded = 9436, value_coded_name_id = 12655 WHERE value_text = 'Inconclusive';
        UPDATE obs SET value_text = null, value_coded = 2895, value_coded_name_id = 3115 WHERE concept_id = 7998 and value_text IN ('Alive');
        UPDATE obs SET value_text = null, value_coded = 7804, value_coded_name_id = 10669 WHERE concept_id = 7998 and value_text IN ('Fresh Still Birth (FSB)');
        UPDATE obs SET value_text = null, value_coded = 7803, value_coded_name_id = 10668 WHERE concept_id = 7998 and value_text IN ('Macerated Still Birth (MSB)');
        UPDATE obs SET value_text = null, value_coded = 7975, value_coded_name_id = 10922 WHERE concept_id = 7998 and value_text IN ('Still Birth')
      SQL
      print_time message: 'Updating observations'
      statements.split(';').each { |value| central_hub message: nil, query: value.strip }
      print_time
    end
    # rubocop:enable Metrics/MethodLength

    # rubocop:disable Metrics/MethodLength
    # method to create migration residuals so that there can be a trace of how data was migrated
    def create_migration_residuals
      central_hub query: "DROP TABLE IF EXISTS #{@database}.migration_mapping"
      statement = <<~SQL
        CREATE TABLE #{@database}.migration_mapping(
          parameter_name varchar(50) NOT NULL,parameter_value INT NOT NULL,primary key (parameter_name))
      SQL
      central_hub query: statement
      statement = <<~SQL
        INSERT INTO #{@database}.migration_mapping(parameter_name, parameter_value)
        VALUES ('max_person_id', '#{@person_id}'),('max_user_id', '#{@user_id}'),
        ('max_patient_program_id', '#{@patient_program_id}'),('max_encounter_id', '#{@encounter_id}'),
        ('max_obs_id', '#{@obs_id}'),('max_order_id', '#{@order_id}')
      SQL
      central_hub query: statement
    end
    # rubocop:enable Metrics/MethodLength

    # rubocop:disable Metrics/MethodLength
    # method to remove holding tables
    def remove_holding_tables
      statements = <<~SQL
        DROP TABLE IF EXISTS #{@database}.reverse_mapping;
        DROP TABLE IF EXISTS #{@database}.patient_migration_mapping;
        DROP TABLE IF EXISTS #{@database}.ART_patient_not_in_use;
        DROP TABLE IF EXISTS #{@database}.ART_patient_identifier_not_in_use;
        DROP TABLE IF EXISTS #{@database}.ART_patient_identifier_in_use;
        DROP TABLE IF EXISTS #{@database}.ART_patient_in_use
      SQL
      print_time message: 'Removing holding tables'
      statements.split(';').each { |value| central_hub message: nil, query: value.strip }
      print_time
    end
    # rubocop:enable Metrics/MethodLength

    # method to execute migration commands
    def central_hub(message: nil, query: nil)
      print_time message: message if message
      central_execute query
      print_time if message
    end

    # method for central execution
    def central_execute(query)
      ActiveRecord::Base.connection.execute query
    end

    # method to print time when running some heavy things
    def print_time(message: 'Done', long_form: false)
      puts "#{message}: #{long_form ? Time.now : Time.now.strftime('%H:%M:%S')}"
    end

    # Section of checking existance of tables

    # method that check whether the user bak was already created
    # if it was already created it means some migrations happened alread
    # else data has never been updated
    def check_user_bak?
      result = ActiveRecord::Base.connection.select_one <<~SQL
        SELECT count(*) AS count
        FROM information_schema.tables
        WHERE table_schema = "#{@database}"
        AND table_name = 'user_bak'
      SQL
      !result['count'].zero?
    end

    # check if the data was reversed
    def check_patient_in_use?
      result = ActiveRecord::Base.connection.select_one <<~SQL
        SELECT count(*) AS count
        FROM information_schema.tables
        WHERE table_schema = "#{@database}"
        AND table_name = 'ART_patient_in_use'
      SQL
      !result['count'].zero?
    end

    # check if this migration was done by the old bash script or was done by ruby
    def check_migration_map?
      result = ActiveRecord::Base.connection.select_one <<~SQL
        SELECT count(*) AS count
        FROM information_schema.tables
        WHERE table_schema = "#{@database}"
        AND table_name = 'migration_mapping'
      SQL
      !result['count'].zero?
    end

    # method to get user id from map
    def user_id_from_map
      id = ActiveRecord::Base.connection.select_one <<~SQL
        SELECT parameter_value FROM #{@database}.migration_mapping WHERE parameter_name = 'max_user_id'
      SQL
      id['parameter_value']
    end

    # method to get use id from user bak if this migration happened using old script
    def user_id_from_bak
      id = ActiveRecord::Base.connection.select_one <<~SQL
        SELECT (ART_user_id - ANC_user_id) as id FROM #{@database}.user_bak limit 1
      SQL
      id['id']
    end

    # method to return patients who were already migrated
    def migrated_patients
      x = ActiveRecord::Base.connection.select_all <<~SQL
        SELECT patient_id FROM #{@database}.ART_patient_in_use
      SQL
      x.map { |patient| patient['patient_id'].to_i }
    end

    # simple check on migrated patients
    def migrated_patients?
      migrated_patients.length.zero?
    end

    # method to get patient that were not in use
    def patient_not_in_use
      not_in_use = [0]
      x = ActiveRecord::Base.connection.select_all <<~SQL
        SELECT anc_patient_id AS patient_id FROM #{@database}.patient_migration_mapping WHERE art_patient_id IN (SELECT patient_id FROM #{@database}.ART_patient_not_in_use)
      SQL
      y = ActiveRecord::Base.connection.select_all <<~SQL
        SELECT patient_id FROM #{@database}.patient WHERE patient_id NOT IN (SELECT anc_patient_id FROM #{@database}.patient_migration_mapping)
      SQL
      x.map { |patient| not_in_use << patient['patient_id'].to_i }
      y.map { |patient| not_in_use << patient['patient_id'].to_i }
      not_in_use.join(',')
    end

    # section to set session variables

    # get max user id FROM databasebeing migrated to
    def max_user_id
      max_user_id = ActiveRecord::Base.connection.select_one <<~SQL
        SELECT COALESCE((SELECT max(user_id) FROM users),0) AS id
      SQL
      max_user_id['id']
    end

    # get max person_id FROM databasebeing migrated to
    def max_person_id
      max_person_id = ActiveRecord::Base.connection.select_one <<~SQL
        SELECT COALESCE((SELECT max(person_id) FROM person),0) AS id
      SQL
      max_person_id['id']
    end

    # get max patient_program_id FROM databasebeing migrated to
    def max_patient_program_id
      table_id = ActiveRecord::Base.connection.select_one <<~SQL
        SELECT COALESCE((SELECT max(patient_program_id) FROM patient_program),0) AS id
      SQL
      table_id['id']
    end

    # get max observation id FROM databasebeing migrated to
    def max_obs_id
      table_id = ActiveRecord::Base.connection.select_one <<~SQL
        SELECT COALESCE((SELECT max(obs_id) FROM obs),0) AS id
      SQL
      table_id['id']
    end

    # get max patient_program_id FROM databasebeing migrated to
    def max_encounter_id
      table_id = ActiveRecord::Base.connection.select_one <<~SQL
        SELECT COALESCE((SELECT max(encounter_id) FROM encounter),0) AS id
      SQL
      table_id['id']
    end

    # get max order id FROM databasebeing migrated to
    def max_order_id
      table_id = ActiveRecord::Base.connection.select_one <<~SQL
        SELECT COALESCE((SELECT max(order_id) FROM orders),0) AS id
      SQL
      table_id['id']
    end
  end
  # rubocop:enable Metrics/ClassLength
end
