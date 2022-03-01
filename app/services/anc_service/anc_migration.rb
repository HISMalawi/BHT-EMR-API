# frozen_string_literal: true

module ANCService
  # rubocop:disable Metrics/ClassLength
  # Class managing the migration of anc data to
  class ANCMigration
    include ActionView::Helpers::DateHelper
    def initialize(database, confidence)
      @person_id = max_person_id
      @user_id = max_user_id
      @patient_program_id = max_patient_program_id
      @encounter_id = max_encounter_id
      @obs_id = max_obs_id
      @order_id = max_order_id
      @database = database
      @confidence = confidence
      @log = File.new('migration.log', 'w+')
      @file = File.new("migration_#{Time.now.strftime('%Y%m%d')}.csv", 'w+')
    end

    # rubocop:disable Metrics/MethodLength
    # main method to do the workflow
    def main
      start_time = Time.now
      @backup = check_user_bak?
      @database_reversed = check_patient_in_use?
      if @backup
        if @database_reversed
          @user_id = check_migration_map? ? user_id_from_map : user_id_from_bak
          normal
        else
          @log.puts 'Migration already happened you might want to reverse first before running this.'
          puts 'Migration already happened you might want to reverse first before running this.'
          return
        end
      else
        normal
      end
      log = "Migration took #{time_ago_in_words(Time.now - (Time.now - start_time), include_seconds: true)}"
      puts log
      @log.puts log
      write_migration_to_file
    end
    # rubocop:enable Metrics/MethodLength

    private

    # rubocop:disable Metrics/MethodLength
    # rubocop:disable Metrics/AbcSize
    # method to execute normal migration
    def normal
      msg = @database_reversed ? 'Starting an abnormal migration (KAWALE CASE)' : 'Starting a normal migration'
      print_time message: msg, long_form: true
      # ANCMappingMigration.new(@database, @confidence).map_linkage_between_anc_and_openmrs
      not_linked = fetch_unmapped_patients
      mapped = fetch_mapped_patients
      # rubocop:disable Metrics/BlockLength
      ActiveRecord::Base.transaction do
        unless @database_reversed
          ActiveRecord::Base.connection.disable_referential_integrity do
            create_user_bak
            migrate_users
            migrate_person(fetch_user_person_id, 'Migratating user specific person records')
            migrate_person_name(fetch_user_person_id, 'Migrating system users name records')
          end
        end
        if @database_reversed
          ActiveRecord::Base.connection.disable_referential_integrity do
            @missed_users_person_ids = fetch_missed_users('person_id')
            @missed_users_ids = fetch_missed_users('user_id')
            migrate_person(@missed_users_person_ids, 'Migrating Missed Users Person Details')
            migrate_person_name(@missed_users_person_ids, 'Migrating Missed User Person Name Details')
            add_missed_users_in_user_bak
            migrate_missed_users
          end
        end
        update_openmrs_users
        migrate_user_role
        migrate_person(fetch_missed_persons, 'Migrating Person details who are neither patients nor system users')
        # migrate_person(fetch_missed_patients, 'Migrating Person details for missed patients')
        migrate_person(not_linked, 'Migrating Person Details for those without any linkage')
        migrate_person_name(fetch_missed_persons, 'Migrating Person Name details who are neither patients nor system users')
        # migrate_person_name(fetch_missed_patients, 'Migrating Person Name details for missed patients')
        migrate_person_name(not_linked, 'Migrating Person Name Details for those without any linkage')
        migrate_person_address(fetch_missed_persons, 'Migrating Person Address details who are neither patients nor system users')
        # migrate_person_address(fetch_missed_patients, 'Migrating Person Address details for missed patients')
        migrate_person_address(not_linked, 'Migrating Person Address Details for those without any linkage')
        migrate_person_attribute(fetch_missed_persons, 'Migrating Person Attributes details who are neither patients nor system users')
        # migrate_person_attribute(fetch_missed_patients, 'Migrating Person Attributes details for missed patients')
        migrate_person_attribute(not_linked, 'Migrating Person Attributes Details for those without any linkage')
        migrate_patient(not_linked, 'Migrating Patient Details for those without any linkage')
        # migrate_patient(fetch_missed_patients, 'Migrating Patient Details for missed patients')
        migrate_patient_identifier(not_linked, 'Migrating Patient Identifier Details for those without any linkage')
        # migrate_patient_identifier(fetch_missed_patients, 'Migrating Patient Details for missed patients')
        # migrate_patient_program(fetch_missed_patients, 'Migrating Patient Program Details for missed patients')
        migrate_patient_program(mapped, 'Migrating Patient Program Details for those linked', linked: true)
        migrate_patient_program(not_linked, 'Migrating Patient Program Details for those without any linkage')
        # migrate_patient_state(fetch_missed_patients, 'Migrating Patient State Details for missed patients')
        migrate_patient_state(mapped, 'Migrating Patient State for those linked')
        provider_change_history
        change_provider_to_the_default_system_user
        migrate_patient_state(not_linked, 'Migrating Patient State for those without any linkage')
        # migrate_encounter_system_users(fetch_missed_patients, 'Migrating Patient encounter for missed patients')
        migrate_encounter_system_users(mapped,
                                       'Migrating Patient encounter details for those linked whose provider is a system user', linked: true)
        migrate_encounter_system_users(not_linked,
                                       'Migrating Patient encounter details for those without any linkage whose provider is a system user')
        # migrate_obs(fetch_missed_patients, 'Migrating Patient Observations for missed patients')
        migrate_obs(mapped, 'Migratig patient observations for those linked', linked: true)
        migrate_obs(not_linked, 'Migrating patient observations for those without any linkage')
        # migrate_orders(fetch_missed_patients, 'Migrating Patient orders for missed patients')
        migrate_orders(mapped, 'Migrating patient orders for those linked', linked: true)
        migrate_orders(not_linked, 'Migrating patient orders for those without any linkage')
        # migrate_drug_order(fetch_missed_patients, 'Migrating Patient Drug orders for missed patients')
        migrate_drug_order(mapped, 'Migrating patient drug orders for those linked')
        migrate_drug_order(not_linked, 'Migrating patient drug orders for those without any linkage')
        if @database_reversed
          ANCService::ANCMissedMigration.new({ max_person_id: @person_id,
                                               max_user_id: @user_id, max_patient_program_id: @patient_program_id,
                                               max_encounter_id: @encounter_id, max_obs_id: @obs_id,
                                               max_order_id: @order_id, database: @database }).main
        end
        update_migrated_records
      end
      # rubocop:enable Metrics/BlockLength
      create_migration_residuals
      remove_holding_tables if @database_reversed
      msg = @database_reversed ? 'Abnormal migratrion finished' : 'Normal migratrion finished'
      print_time message: msg, long_form: true
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/MethodLength

    # method to get users person ids
    def fetch_user_person_id
      result = ActiveRecord::Base.connection.select_all <<~SQL
        SELECT person_id FROM #{@database}.users
      SQL
      result.map { |person| person['person_id'] }.push(0).join(',')
    end

    # method to fetch linked patients
    def fetch_mapped_patients
      condition = ''
      condition = "WHERE art_patient_id NOT IN (SELECT patient_id FROM #{@database}.ART_patient_in_use)" if @database_reversed
      result = ActiveRecord::Base.connection.select_all <<~SQL
        SELECT anc_patient_id, art_patient_id FROM #{@database}.mapped_patients #{condition}
      SQL
      result.map { |person| person['anc_patient_id'] }.push(0).join(',')
    end

    # method to fetch patients without any link
    def fetch_unmapped_patients
      result = ActiveRecord::Base.connection.select_all <<~SQL
        SELECT anc_patient_id FROM #{@database}.unmapped_patients
      SQL
      result.map { |record| record['anc_patient_id'] }.push(0).join(',')
    end

    # # method to execute a migration after a reversal was done
    # def abnormal
    #   print_time message: 'Starting an abnormal migration (KAWALE CASE)', long_form: true
    #   begin
    #     map_linkage_between_anc_and_openmrs
    #     ActiveRecord::Base.transaction do
    #       update_openmrs_users
    #       migrate_person
    #       migrate_person_name
    #       migrate_person_address
    #       migrate_person_attribute
    #       migrate_patient
    #       migrate_patient_identifier
    #       migrate_patient_program
    #       migrate_patient_state
    #       migrate_encounter
    #       migrate_obs
    #       migrate_orders
    #       migrate_drug_order
    #       ANCService::ANCMissedMigration.new({ max_person_id: @person_id,
    #                                            max_user_id: @user_id, max_patient_program_id: @patient_program_id,
    #                                            max_encounter_id: @encounter_id, max_obs_id: @obs_id,
    #                                            max_order_id: @order_id, database: @database }).main

    #       update_migrated_records
    #     end
    #     create_migration_residuals

    #   rescue StandardError => e
    #     puts e.message[0..1000]
    #   end
    #   print_time message: , long_form: true
    # end

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

    def add_missed_users_in_user_bak
      statement = <<~SQL
        INSERT INTO #{@database}.user_bak (ANC_user_id, ART_user_id, person_id)
        SELECT user_id, (SELECT (SELECT MAX(user_id) FROM users) + user_id), (SELECT #{@person_id} + person_id)
        FROM #{@database}.users
        WHERE user_id IN (#{@missed_users_ids})
      SQL
      central_hub message: 'Updating user_bak with missed/new users', query: statement
    end

    def fetch_missed_users(field)
      result = ActiveRecord::Base.connection.select_all <<~SQL
        SELECT #{field}
        FROM #{@database}.users
        WHERE user_id NOT IN (SELECT ANC_user_id FROM #{@database}.user_bak)
      SQL
      result.map { |record| record[field] }.push(0).join(',')
    end

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
        SELECT b.ART_user_id, users.system_id,  CONCAT(users.username, '_anc'),  users.password,  users.salt,  users.secret_question,  users.secret_answer, creators.ART_user_id,  users.date_created, changers.ART_user_id,  users.date_changed, b.person_id, users.retired, voiders.ART_user_id, users.date_retired,  users.retire_reason,  users.uuid,  users.authentication_token
        FROM #{@database}.users
        INNER JOIN #{@database}.user_bak b on b.ANC_user_id = users.user_id
        INNER JOIN #{@database}.user_bak creators on creators.ANC_user_id = users.creator
        LEFT JOIN #{@database}.user_bak changers on changers.ANC_user_id = users.changed_by
        LEFT JOIN #{@database}.user_bak voiders on voiders.ANC_user_id = users.retired_by
      SQL
      central_hub message: 'Migrating users records', query: statement
    end

    # method to migrate missed users
    def migrate_missed_users
      statement = <<~SQL
        INSERT INTO users (user_id,  system_id,  username,  password,  salt,  secret_question,  secret_answer,  creator,  date_created,  changed_by,  date_changed,  person_id,  retired,  retired_by,  date_retired,  retire_reason,  uuid,  authentication_token)
        SELECT b.ART_user_id, users.system_id,  CONCAT(users.username, '_anc'),  users.password,  users.salt,  users.secret_question,  users.secret_answer, creators.ART_user_id,  users.date_created, changers.ART_user_id,  users.date_changed, b.person_id, users.retired, voiders.ART_user_id, users.date_retired,  users.retire_reason,  users.uuid,  users.authentication_token
        FROM #{@database}.users
        INNER JOIN #{@database}.user_bak b on b.ANC_user_id = users.user_id
        INNER JOIN #{@database}.user_bak creators on creators.ANC_user_id = users.creator
        LEFT JOIN #{@database}.user_bak changers on changers.ANC_user_id = users.changed_by
        LEFT JOIN #{@database}.user_bak voiders on voiders.ANC_user_id = users.retired_by
        WHERE user_id IN (#{@missed_users_ids})
      SQL
      central_hub message: 'Migrating missed users records', query: statement
    end

    # method to migrate person records
    # rubocop:disable Metrics/MethodLength
    def migrate_person(patients, msg, linked: false)
      cond = ''
      cond = "INNER JOIN #{@database}.mapped_patients on mapped_patients.anc_patient_id = person.person_id" if linked
      statement = <<~SQL
        INSERT INTO person (person_id, gender, birthdate, birthdate_estimated, dead, death_date, cause_of_death, creator, date_created, changed_by, date_changed, voided, voided_by, date_voided, void_reason, uuid)
        SELECT #{linked ? 'art_patient_id' : "(SELECT #{@person_id} + person.person_id) AS person_id"},
        gender, birthdate, birthdate_estimated, dead, death_date, cause_of_death, creators.ART_user_id, person.date_created, changers.ART_user_id, person.date_changed, person.voided, voiders.ART_user_id, person.date_voided, person.void_reason, person.uuid
        FROM #{@database}.person #{cond}
        INNER JOIN #{@database}.user_bak creators ON creators.ANC_user_id = person.creator
        LEFT JOIN #{@database}.user_bak changers ON changers.ANC_user_id = person.changed_by
        LEFT JOIN #{@database}.user_bak voiders ON voiders.ANC_user_id = person.voided_by
        WHERE person.person_id IN (#{patients})
      SQL
      central_hub message: msg, query: statement
    end
    # rubocop:enable Metrics/MethodLength

    # method to migrate person name records
    def migrate_person_name(patients, msg, linked: false)
      cond = ''
      cond = "INNER JOIN #{@database}.mapped_patients on mapped_patients.anc_patient_id = person_name.person_id" if linked
      statement = <<~SQL
        INSERT INTO person_name (preferred, person_id, prefix, given_name, middle_name, family_name_prefix, family_name, family_name2, family_name_suffix, degree, creator, date_created, voided, voided_by, date_voided, void_reason, changed_by, date_changed, uuid)
        SELECT preferred, #{linked ? 'art_patient_id' : "(SELECT #{@person_id} + person_name.person_id) AS person_id"},
        prefix, given_name, middle_name, family_name_prefix, family_name, family_name2, family_name_suffix, degree,creators.ART_user_id, person_name.date_created, voided,voiders.ART_user_id, person_name.date_voided, person_name.void_reason, changers.ART_user_id, person_name.date_changed, person_name.uuid
        FROM #{@database}.person_name #{cond}
        INNER JOIN #{@database}.user_bak creators ON creators.ANC_user_id = person_name.creator
        LEFT JOIN #{@database}.user_bak changers ON changers.ANC_user_id = person_name.changed_by
        LEFT JOIN #{@database}.user_bak voiders ON voiders.ANC_user_id = person_name.voided_by
        WHERE person_name.person_id IN (#{patients})
      SQL
      central_hub message: msg, query: statement
    end

    # method to migrate person address records
    def migrate_person_address(patients, msg, linked: false)
      cond = ''
      cond = "INNER JOIN #{@database}.mapped_patients on mapped_patients.anc_patient_id = p.person_id" if linked
      statement = <<~SQL
        INSERT INTO person_address (person_id,  preferred,  address1,  address2,  city_village,  state_province,  postal_code,  country,  latitude,  longitude,  creator,  date_created,  voided,  voided_by,  date_voided, void_reason, county_district,  neighborhood_cell,  region,  subregion,  township_division,  uuid)
        SELECT #{linked ? 'art_patient_id' : "(SELECT #{@person_id} + p.person_id) AS person_id"},
        p.preferred,  p.address1,  p.address2,  p.city_village,  p.state_province, p.postal_code,  p.country,  p.latitude,  p.longitude, creators.ART_user_id,  p.date_created,  p.voided, voiders.ART_user_id, p.date_voided, p.void_reason, p.county_district,  p.neighborhood_cell,  p.region,  p.subregion,  p.township_division, p.uuid
        FROM #{@database}.person_address p #{cond}
        INNER JOIN #{@database}.user_bak creators ON creators.ANC_user_id = p.creator
        LEFT JOIN #{@database}.user_bak voiders ON voiders.ANC_user_id = p.voided_by
        WHERE p.person_id IN (#{patients})
      SQL
      central_hub message: msg, query: statement
    end

    # method to migrate person attribute records
    def migrate_person_attribute(patients, msg, linked: false)
      cond = ''
      cond = "INNER JOIN #{@database}.mapped_patients on mapped_patients.anc_patient_id = p.person_id" if linked
      statement = <<~SQL
        INSERT INTO person_attribute (person_id, value, person_attribute_type_id, creator, date_created, changed_by, date_changed, voided, voided_by, date_voided, void_reason, uuid)
        SELECT #{linked ? 'art_patient_id' : "(SELECT #{@person_id} + p.person_id) AS person_id"}, p.value, p.person_attribute_type_id, creators.ART_user_id, p.date_created, changers.ART_user_id, p.date_changed, p.voided, voiders.ART_user_id, p.date_voided, p.void_reason, p.uuid
        FROM #{@database}.person_attribute p #{cond}
        INNER JOIN #{@database}.user_bak creators ON creators.ANC_user_id = p.creator
        LEFT JOIN #{@database}.user_bak changers ON changers.ANC_user_id = p.changed_by
        LEFT JOIN #{@database}.user_bak voiders ON voiders.ANC_user_id = p.voided_by
        WHERE p.person_id IN (#{patients})
      SQL
      central_hub message: msg, query: statement
    end

    # method to migrate patient records
    def migrate_patient(patients, msg, linked: false)\
      cond = ''
      cond = "INNER JOIN #{@database}.mapped_patients on mapped_patients.anc_patient_id = p.patient_id" if linked
      statement = <<~SQL
        INSERT INTO patient (patient_id, tribe, creator, date_created, changed_by, date_changed, voided, voided_by, date_voided, void_reason)
        SELECT #{linked ? 'art_patient_id' : "(SELECT #{@person_id} + p.patient_id) AS patient_id"}, p.tribe, creators.ART_user_id, p.date_created, changers.ART_user_id, p.date_changed, p.voided, voiders.ART_user_id, p.date_voided, p.void_reason
        FROM #{@database}.patient p #{cond}
        INNER JOIN #{@database}.user_bak creators ON creators.ANC_user_id = p.creator
        LEFT JOIN #{@database}.user_bak changers ON changers.ANC_user_id = p.changed_by
        LEFT JOIN #{@database}.user_bak voiders ON voiders.ANC_user_id = p.voided_by
        WHERE p.patient_id IN (#{patients})
      SQL
      central_hub message: msg, query: statement
    end

    # method to migrate patient identifier records
    def migrate_patient_identifier(patients, msg, linked: false)
      cond = ''
      cond = "INNER JOIN #{@database}.mapped_patients on mapped_patients.anc_patient_id = p.patient_id" if linked
      statement = <<~SQL
        INSERT INTO patient_identifier (patient_id,  identifier,  identifier_type,  preferred,  location_id,  creator,  date_created,  voided,  voided_by,  date_voided,  void_reason,  uuid)
        SELECT #{linked ? 'art_patient_id' : "(SELECT #{@person_id} + p.patient_id) AS patient_id,"} p.identifier, p.identifier_type,  p.preferred,  p.location_id, creators.ART_user_id,  p.date_created,  p.voided, voiders.ART_user_id, p.date_voided, p.void_reason, p.uuid
        FROM #{@database}.patient_identifier p #{cond}
        INNER JOIN #{@database}.user_bak creators ON creators.ANC_user_id = p.creator
        LEFT JOIN #{@database}.user_bak voiders ON voiders.ANC_user_id = p.voided_by
        WHERE p.patient_id IN (#{patients})
      SQL
      central_hub message: msg, query: statement
    end

    # method to migrate patient program records
    def migrate_patient_program(patients, msg, linked: false)
      cond = ''
      if linked
        cond = "INNER JOIN #{@database}.mapped_patients on mapped_patients.anc_patient_id = patient_program.patient_id"
      end
      statement = <<~SQL
        INSERT INTO patient_program (patient_program_id,  patient_id,  program_id,  date_enrolled,  date_completed,  creator,  date_created, changed_by,  date_changed,  voided, voided_by,  date_voided,  void_reason,  uuid,  location_id)
        SELECT (SELECT #{@patient_program_id} + patient_program_id) AS patient_program_id,  #{linked ? 'art_patient_id' : "(SELECT #{@person_id} + patient_id) AS patient_id"},  program_id,  date_enrolled,  date_completed, creators.ART_user_id, patient_program.date_created, changers.ART_user_id, patient_program.date_changed, patient_program.voided, voiders.ART_user_id, patient_program.date_voided,  patient_program.void_reason, patient_program.uuid, location_id
        FROM #{@database}.patient_program #{cond}
        INNER JOIN #{@database}.user_bak creators ON creators.ANC_user_id = patient_program.creator
        LEFT JOIN #{@database}.user_bak changers ON changers.ANC_user_id = patient_program.changed_by
        LEFT JOIN #{@database}.user_bak voiders ON voiders.ANC_user_id = patient_program.voided_by
        WHERE patient_id IN (#{patients})
      SQL
      central_hub message: msg, query: statement
    end

    # method to migrate patient state records
    def migrate_patient_state(patients, msg)
      statement = <<~SQL
        INSERT INTO patient_state (patient_program_id, state, start_date, end_date, creator, date_created, changed_by, date_changed, voided, voided_by, date_voided, void_reason, uuid)
        SELECT (SELECT #{@patient_program_id} + patient_program_id) AS patient_program_id, state, start_date, end_date, creators.ART_user_id, patient_state.date_created, changers.ART_user_id, patient_state.date_changed, patient_state.voided, voiders.ART_user_id, patient_state.date_voided, patient_state.void_reason, patient_state.uuid
        FROM #{@database}.patient_state
        INNER JOIN #{@database}.user_bak creators ON creators.ANC_user_id = patient_state.creator
        LEFT JOIN #{@database}.user_bak changers ON changers.ANC_user_id = patient_state.changed_by
        LEFT JOIN #{@database}.user_bak voiders ON voiders.ANC_user_id = patient_state.voided_by
        WHERE patient_program_id IN (SELECT patient_program_id FROM #{@database}.patient_program WHERE patient_id IN (#{patients}))
      SQL
      central_hub message: msg, query: statement
    end

    # method to load previous person id
    def prev_person_id
      wow = 0
      if @database_reversed
        result = ActiveRecord::Base.connection.select_one <<~SQL
          SELECT parameter_value FROM #{@database}.reverse_mapping WHERE parameter_name = 'max_person_id'
        SQL
        wow = result['parameter_value'].to_i
      else
        wow = @person_id
      end
      wow
    end

    def fetch_missed_persons
      result = ActiveRecord::Base.connection.select_all <<~SQL
        SELECT person_id FROM #{@database}.person
        WHERE person_id NOT IN (SELECT patient_id FROM #{@database}.patient)
        AND person_id NOT IN (SELECT person_id FROM #{@database}.users)
      SQL
      result.map { |person| person['person_id'] }.push(0).join(',')
    end

    def fetch_missed_patients
      result = ActiveRecord::Base.connection.select_all <<~SQL
        SELECT patient_id FROM #{@database}.patient
        WHERE patient_id NOT IN (
          SELECT patient_id
          FROM #{@database}.patient_identifier
          WHERE identifier_type = 3
          AND voided = 0
        )
      SQL
      result.map { |person| person['patient_id'] }.push(0).join(',')
    end

    def fetch_providers_who_are_not_system_users
      result = ActiveRecord::Base.connection.select_all <<~SQL
        SELECT provider_id FROM #{@database}.encounter
        WHERE provider_id NOT IN (#{fetch_user_person_id})
        GROUP BY provider_id
      SQL
      result.map { |record| record['provider_id'] }.push(0).join(',')
    end

    def change_provider_to_the_default_system_user
      return if fetch_providers_who_are_not_system_users.length == 1

      statement = <<~SQL
        UPDATE #{@database}.encounter SET provider_id = (SELECT person_id FROM #{@database}.users LIMIT 1) WHERE provider_id IN (#{fetch_providers_who_are_not_system_users})
      SQL
      central_hub message: 'Updating providers that are not system users to a default system users', query: statement
    end

    def provider_change_history
      return if fetch_providers_who_are_not_system_users.length == 1

      central_hub(message: 'Dropping recorded providers table', query: "DROP TABLE IF EXISTS #{@database}.provider_change_history")
      statement = <<~SQL
        CREATE TABLE #{@database}.provider_change_history
        SELECT provider_id AS ANC_person_id, encounter_id AS ANC_encounter_id, (SELECT person_id FROM #{@database}.users LIMIT 1) AS ANC_new_person_id, (SELECT (SELECT person_id FROM #{@database}.users LIMIT 1) + #{@person_id}) AS ART_provider_id, (SELECT #{@encounter_id} + encounter_id) AS ART_encounter_id
        FROM #{@database}.encounter
        WHERE provider_id IN (#{fetch_providers_who_are_not_system_users})
      SQL
      central_hub(message: 'Recording providers who are not systems users', query: statement)
    end

    # method to migrate encounter whose providers are system users
    # rubocop:disable Metrics/MethodLength
    def migrate_encounter_system_users(patients, msg, linked: false)
      cond = ''
      cond = "INNER JOIN #{@database}.mapped_patients on mapped_patients.anc_patient_id = encounter.patient_id" if linked
      statement = <<~SQL
        INSERT INTO encounter (encounter_id, encounter_type, patient_id, provider_id, location_id, form_id, encounter_datetime, creator, date_created, voided, voided_by, date_voided, void_reason, uuid, changed_by, date_changed, program_id)
        SELECT (SELECT #{@encounter_id} + encounter_id), encounter_type, #{linked ? 'art_patient_id' : "(SELECT #{@person_id} + patient_id)"}, providers.ART_person_id, location_id, form_id, encounter_datetime, bak.ART_user_id, encounter.date_created, encounter.voided, voider.ART_user_id, encounter.date_voided, encounter.void_reason, encounter.uuid, changer.ART_user_id, encounter.date_changed, 12
        FROM #{@database}.encounter #{cond}
        INNER JOIN #{@database}.user_bak bak ON encounter.creator = bak.ANC_user_id
        INNER JOIN (
          SELECT u.person_id ANC_person_id, b.person_id ART_person_id
          FROM #{@database}.users u
          INNER JOIN #{@database}.user_bak b ON b.ANC_user_id = u.user_id
        ) providers ON providers.ANC_person_id = encounter.provider_id
        LEFT JOIN #{@database}.user_bak voider on voider.ANC_user_id = encounter.voided_by
        LEFT JOIN #{@database}.user_bak changer on changer.ANC_user_id = encounter.changed_by
        WHERE provider_id IN (SELECT person_id FROM #{@database}.users) AND patient_id IN (#{patients})
      SQL
      central_hub message: msg, query: statement
    end
    # rubocop:enable Metrics/MethodLength

    # method to migrate obs records
    def migrate_obs(patients, msg, linked: false)
      cond = ''
      cond = "INNER JOIN #{@database}.mapped_patients on mapped_patients.anc_patient_id = obs.person_id" if linked
      statement = <<~SQL
        INSERT INTO obs (obs_id, person_id,  concept_id,  encounter_id,  order_id,  obs_datetime,  location_id,  obs_group_id,  accession_number,  value_group_id,  value_boolean,  value_coded,  value_coded_name_id,  value_drug,  value_datetime,  value_numeric,  value_modifier,  value_text,  date_started,  date_stopped,  comments,  creator,  date_created,  voided,  voided_by,  date_voided,  void_reason,  value_complex,  uuid)
        SELECT (SELECT #{@obs_id} + obs_id) AS obs_id, #{linked ? 'art_patient_id' : "(SELECT #{@person_id} + obs.person_id) AS person_id"},  concept_id,  (SELECT #{@encounter_id} + encounter_id) AS encounter_id,  (SELECT #{@order_id} + order_id) AS order_id, obs_datetime, location_id, (SELECT #{@obs_id} + obs_group_id) AS obs_group_id, accession_number, value_group_id, value_boolean, value_coded, value_coded_name_id, value_drug, value_datetime, value_numeric, value_modifier, value_text, date_started, date_stopped,  comments, creators.ART_user_id, obs.date_created, obs.voided, voiders.ART_user_id, obs.date_voided, obs.void_reason, value_complex,  obs.uuid
        FROM #{@database}.obs #{cond}
        INNER JOIN #{@database}.user_bak creators ON creators.ANC_user_id = obs.creator
        LEFT JOIN #{@database}.user_bak voiders ON voiders.ANC_user_id = obs.voided_by
        WHERE encounter_id IN (SELECT encounter_id FROM #{@database}.encounter WHERE patient_id IN (#{patients}))
      SQL
      central_hub message: msg, query: statement
    end

    # method to migrate orders records
    def migrate_orders(patients, msg, linked: false)
      cond = ''
      cond = "INNER JOIN #{@database}.mapped_patients on mapped_patients.anc_patient_id = orders.patient_id" if linked
      statement = <<~SQL
        INSERT INTO orders (order_id, order_type_id, concept_id, orderer,  encounter_id,  instructions,  start_date,  auto_expire_date,  discontinued,  discontinued_date, discontinued_by,  discontinued_reason, creator, date_created,  voided,  voided_by,  date_voided,  void_reason, patient_id,  accession_number, obs_id,  uuid, discontinued_reason_non_coded)
        SELECT (SELECT #{@order_id} + order_id) AS order_id,  order_type_id, concept_id, orderer, (SELECT #{@encounter_id} + encounter_id) AS encounter_id,  instructions, start_date, auto_expire_date,  discontinued,  discontinued_date, changers.ART_user_id,  discontinued_reason,  creators.ART_user_id,  orders.date_created,  orders.voided, voiders.ART_user_id,  orders.date_voided, orders.void_reason, #{linked ? 'art_patient_id' : "(SELECT #{@person_id} + patient_id) AS patient_id"}, accession_number, (SELECT #{@obs_id} + obs_id) AS obs_id, orders.uuid, discontinued_reason_non_coded
        FROM #{@database}.orders #{cond}
        INNER JOIN #{@database}.user_bak creators ON creators.ANC_user_id = orders.creator
        LEFT JOIN #{@database}.user_bak changers ON changers.ANC_user_id = orders.discontinued_by
        LEFT JOIN #{@database}.user_bak voiders ON voiders.ANC_user_id = orders.voided_by
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

    def migrate_user_role
      statement = <<~SQL
        INSERT INTO user_role (user_id, role)
        SELECT b.ART_user_id, r.role
        FROM #{@database}.user_role r
        INNER JOIN #{@database}.user_bak b on r.user_id = b.ANC_user_id
        WHERE NOT EXISTS (SELECT 1 FROM user_role WHERE user_role.user_id = b.ART_user_id)
      SQL
      central_hub(message: 'Migrating user roles', query: statement)
    end

    # rubocop:disable Metrics/MethodLength
    # method to update migated records
    def update_migrated_records
      statements = <<~SQL
        UPDATE encounter SET encounter_type = 98 WHERE encounter_type = 61 AND encounter_id > #{@encounter_id};
        UPDATE obs SET value_text = null, value_coded = 1065, value_coded_name_id = 1102 WHERE concept_id = 2723 AND value_text IN ('Given during previous ANC visit for current pregnancy', 'Given Today', 'Yes') AND obs_id > #{@obs_id};
        UPDATE obs SET value_text = null, value_coded = 1066, value_coded_name_id = 1103 WHERE concept_id = 2723 AND value_text IN ('No', 'Not given today or during current pregnancy') AND obs_id > #{@obs_id};
        UPDATE #{@database}.obs SET value_text = null, value_coded = 1067, value_coded_name_id = 1104 WHERE concept_id = 2723 AND value_text IN ('Unknown');
        UPDATE obs SET value_text = null, value_coded = 1065, value_coded_name_id = 1102 WHERE value_text = 'Yes' AND obs_id > #{@obs_id};
        UPDATE obs SET value_text = null, value_coded = 1066, value_coded_name_id = 1103 WHERE value_text = 'No' AND obs_id > #{@obs_id};
        UPDATE obs SET value_text = null, value_coded = 1067, value_coded_name_id = 1104 WHERE value_text = 'Unknown' AND obs_id > #{@obs_id};
        UPDATE obs SET value_text = null, value_coded = 703, value_coded_name_id = 718 WHERE value_text = 'Positive' AND obs_id > #{@obs_id};
        UPDATE obs SET value_text = null, value_coded = 664, value_coded_name_id = 678 WHERE value_text = 'Negative' AND obs_id > #{@obs_id};
        UPDATE obs SET value_text = null, value_coded = 2475, value_coded_name_id = 5944 WHERE value_text = 'Not Done' AND obs_id > #{@obs_id};
        UPDATE obs SET value_text = null, value_coded = 9436, value_coded_name_id = 12655 WHERE value_text = 'Inconclusive' AND obs_id > #{@obs_id};
        UPDATE obs SET value_text = null, value_coded = 2895, value_coded_name_id = 3115 WHERE concept_id = 7998 AND value_text IN ('Alive') AND obs_id > #{@obs_id};
        UPDATE obs SET value_text = null, value_coded = 7804, value_coded_name_id = 10669 WHERE concept_id = 7998 AND value_text IN ('Fresh Still Birth (FSB)') AND obs_id > #{@obs_id};
        UPDATE obs SET value_text = null, value_coded = 7803, value_coded_name_id = 10668 WHERE concept_id = 7998 AND value_text IN ('Macerated Still Birth (MSB)') AND obs_id > #{@obs_id};
        UPDATE obs SET value_text = null, value_coded = 7975, value_coded_name_id = 10922 WHERE concept_id = 7998 AND value_text IN ('Still Birth') AND obs_id > #{@obs_id}
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
      log = "#{message}: #{long_form ? Time.now : Time.now.strftime('%H:%M:%S')}"
      puts log
      @log.puts log
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

    def report_mapped_patients
      result = ActiveRecord::Base.connection.select_all <<~SQL
        SELECT * FROM #{@database}.mapped_patients
      SQL
      csv = 'ANC PATIENT ID,ART PATIENT ID,ANC PATIENT IDENTIFIER,ART PATIENT IDENTIFIER,REASON FOR CHANGE'
      result.each do |record|
        csv += "\n#{record['anc_patient_id']},#{record['art_patient_id']},#{record['anc_identifier']},#{record['art_identifier']},#{record['reason']}"
      end
      csv
    end

    def report_unmapped_patients
      result = ActiveRecord::Base.connection.select_all <<~SQL
        SELECT * FROM #{@database}.unmapped_patients
      SQL
      csv = 'ANC PATIENT ID,ART PATIENT ID,PATIENT IDENTIFIER'
      result.each do |record|
        csv += "\n#{record['anc_patient_id']},#{record['anc_patient_id'].to_i + @person_id},#{record['identifier']}"
      end
      csv
    end

    def report_patients_not_enrolled
      result = ActiveRecord::Base.connection.select_all <<~SQL
        SELECT anc_patient_id, art_patient_id,anc_identifier,art_identifier
        FROM #{@database}.mapped_patients
        WHERE NOT EXISTS (SELECT 1 FROM #{@database}.patient_program WHERE patient_program.patient_id = mapped_patients.anc_patient_id)
      SQL
      csv = 'ANC PATIENT ID,ART PATIENT ID,PATIENT IDENTIFIER'
      result.each do |record|
        csv += "\n#{record['anc_patient_id']},#{record['art_patient_id']},#{record['anc_identifier']},#{record['art_identifier']}"
      end
      csv += report_patients_not_enrolled_and_not_mapped
    end

    def report_patients_not_enrolled_and_not_mapped
      result = ActiveRecord::Base.connection.select_all <<~SQL
        SELECT anc_patient_id,identifier
        FROM #{@database}.unmapped_patients
        WHERE NOT EXISTS (SELECT 1 FROM #{@database}.patient_program WHERE patient_program.patient_id = unmapped_patients.anc_patient_id)
      SQL
      csv = ''
      result.each do |record|
        csv += "\n#{record['anc_patient_id']},#{record['anc_patient_id'].to_i + @person_id},#{record['identifier']},#{record['identifier']}"
      end
      csv
    end

    def report_patient_without_encounters
      result = ActiveRecord::Base.connection.select_all <<~SQL
        SELECT anc_patient_id, art_patient_id,anc_identifier,art_identifier
        FROM #{@database}.mapped_patients
        WHERE NOT EXISTS (SELECT 1 FROM #{@database}.encounter WHERE encounter.patient_id = mapped_patients.anc_patient_id AND voided = 0)
      SQL
      csv = 'ANC PATIENT ID,ART PATIENT ID,ANC IDENTIFIER,ART IDENTIFIER'
      result.each do |record|
        csv += "\n#{record['anc_patient_id']},#{record['art_patient_id']},#{record['anc_identifier']},#{record['art_identifier']}"
      end
      csv += report_patient_without_encounters_and_not_mapped
    end

    def report_patient_without_encounters_and_not_mapped
      result = ActiveRecord::Base.connection.select_all <<~SQL
        SELECT anc_patient_id,identifier
        FROM #{@database}.unmapped_patients
        WHERE NOT EXISTS (SELECT 1 FROM #{@database}.encounter WHERE encounter.patient_id = unmapped_patients.anc_patient_id)
      SQL
      csv = ''
      result.each do |record|
        csv += "\n#{record['anc_patient_id']},#{record['anc_patient_id'].to_i + @person_id},#{record['identifier']},#{record['identifier']}"
      end
      csv
    end

    def report_providers_changed
      result = ActiveRecord::Base.connection.select_all <<~SQL
        SELECT anc_person_id, art_person_id,anc_encounter_id,art_encounter_id
        FROM #{@database}.provider_change_history
      SQL
      csv = 'ANC PROVIDER ID ,ART PROVIDER ID,ANC ENCOUNTER ID,ART ENCOUNTER ID'
      result.each do |record|
        csv += "\n#{record['anc_person_id']},#{record['art_person_id']},#{record['anc_encounter_id']},#{record['art_encounter_id']}"
      end
      csv
    end

    # method to write mapping data
    def write_migration_to_file
      @log.close
      @file.puts "This is a report of ANC Migration that happened on #{Time.now.to_date}. Confidence percentage was set to #{@confidence}"
      @file.puts 'This is a list of Mapped Patients'
      @file.puts report_mapped_patients
      @file.puts ' '
      @file.puts 'This is a list of Patient without any link'
      @file.puts report_unmapped_patients
      @file.puts ' '
      @file.puts 'This is a list of Patients without program enrollment records'
      @file.puts report_patients_not_enrolled
      @file.puts ' '
      @file.puts 'This is a list of Patients without encounters'
      @file.puts report_patient_without_encounters
      @file.puts ' '
      @file.puts 'This is list of Providers that were changed because they are not system users'
      @file.puts report_providers_changed
      @file.puts 'This is the log'
      @file.puts File.open('migration.log').read
      File.delete('migration.log') if File.exist?('migration.log')
      @file.close
    end
  end
  # rubocop:enable Metrics/ClassLength
end
