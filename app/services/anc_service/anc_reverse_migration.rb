# frozen_string_literal: true

module ANCService
  # rubocop:disable Metrics/ClassLength
  # class to handle reversing of anc migrated data
  # in true sense we are just deleting the records
  class ANCReverseMigration
    def initialize(params)
      @database = params[:database]
      @date = params[:migration_date]
    end

    # rubocop:disable Metrics/MethodLength
    # rubocop:disable Metrics/AbcSize
    # method to start removing anc migrated data
    def main
      print_time message: 'Starting migration reversal script', long_form: true
      @users = user_list
      patient_in_use
      @patients = patient_list
      patient_identifier_in_use
      patient_not_in_use
      @remove = remove_list
      patient_identifier_not_in_use
      patient_mapping
      create_reverse_residuals
      begin
        ActiveRecord::Base.transaction do
          ActiveRecord::Base.connection.disable_referential_integrity do
            remove_drug_orders
            remove_orders
            remove_obs
            remove_concept_proposal
            remove_encounters
            remove_patient_state
            remove_patient_program
            remove_patient_identifier
            remove_patient
            remove_person_attribute
            remove_person_address
            remove_person_name
            remove_person
          end
        end
      rescue StandardError => e
        puts e.message[0..1000]
        # puts exception.backtrace
      end
      print_time message: 'Finished migration reversal script', long_form: true
    end
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/AbcSize

    private

    # method to map patients that are already being used
    def patient_in_use
      central_execute statement: "DROP TABLE IF EXISTS #{@database}.ART_patient_in_use"
      statement = <<~SQL
        CREATE TABLE #{@database}.ART_patient_in_use AS
        SELECT p.patient_id
        FROM patient p
        INNER JOIN encounter e ON p.patient_id = e.patient_id
        WHERE p.creator IN (#{@users}) AND e.date_created >= DATE('#{@date}')
        GROUP BY p.patient_id HAVING COUNT(*) > 0;
      SQL
      central_execute message: 'Saving patients in use', statement: statement
    end

    # method to map patient that not being used
    def patient_identifier_in_use
      central_execute statement: "DROP TABLE IF EXISTS #{@database}.ART_patient_identifier_in_use"
      statement = <<~SQL
        CREATE TABLE #{@database}.ART_patient_identifier_in_use AS
        SELECT e.patient_id, e.identifier
        FROM patient_identifier e
        WHERE e.patient_id IN (#{@patients})
      SQL
      central_execute message:'Saving identifiers in use', statement: statement
      central_execute statement: "ALTER TABLE #{@database}.ART_patient_identifier_in_use ADD INDEX identifier_in_use (patient_id)"
    end

    # method to get identifiers for patients not in use
    def patient_identifier_not_in_use
      central_execute statement: "DROP TABLE IF EXISTS #{@database}.ART_patient_identifier_not_in_use"
      statement <<~SQL
        CREATE TABLE #{@database}.ART_patient_identifier_not_in_use AS
        SELECT e.patient_id, e.identifier
        FROM patient_identifier e
        WHERE e.patient_id IN (SELECT p.patient_id FROM #{@database}.ART_patient_not_in_use p)
      SQL
      central_execute 'Save identifier not used', statement
      central_execute statement:
                      "ALTER TABLE #{@database}.ART_patient_identifier_not_in_use ADD INDEX identifier_not_in_use (patient_id)"
    end

    # method to map patient that not being used
    def patient_not_in_use
      central_execute statement: "DROP TABLE IF EXISTS #{@database}.ART_patient_not_in_use"
      statement = <<~SQL
        CREATE TABLE #{@database}.ART_patient_not_in_use AS
        SELECT p.patient_id
        FROM patient p
        WHERE p.creator IN (#{@users}) AND p.patient_id NOT IN (#{@patients})
      SQL
      central_execute 'Add patients to not in use', statement
    end

    # rubocop:disable Metrics/MethodLength
    # method to map all patients
    def patient_mapping
      central_execute statement: "DROP TABLE IF EXISTS #{@database}.patient_migration_mapping"
      stmt = <<~SQL
        CREATE TABLE #{@database}.patient_migration_mapping
        SELECT DISTINCT(anc.patient_id) AS anc_patient_id, art.patient_id AS art_patient_id
        FROM #{@database}.patient_identifier anc
        JOIN patient_identifier art ON anc.identifier = art.identifier
        JOIN #{@database}.user_bak bak ON anc.creator = bak.ANC_user_id
        WHERE art.creator = bak.ART_user_id AND art.date_created = anc.date_created
      SQL
      central_execute 'Create patient mapping', stmt
      central_execute statement: "ALTER TABLE #{@database}.patient_migration_mapping add primary key (anc_patient_id)"
    end
    # rubocop:enable Metrics/MethodLength

    # rubocop:disable Metrics/MethodLength
    # method to create reverse residuals so that there can be a trace of how data was before reverse
    # even though this doesn't make sense
    def create_reverse_residuals
      central_execute statement: "DROP TABLE IF EXISTS #{@database}.reverse_mapping"
      statement = <<~SQL
        CREATE TABLE #{@database}.reverse_mapping(
          parameter_name varchar(50) NOT NULL,parameter_value INT NULL,
          primary key (parameter_name)
        )
      SQL
      central_execute statement: statement
      if check_mapping?
        statement = <<~SQL
          INSERT INTO #{@database}.reverse_mapping(parameter_name, parameter_value)
          SELECT parameter_name, paramter_value FROM #{@database}.migration_mapping
        SQL
      else
        all_anc_in_openmrs
        statement = <<~SQL
          INSERT INTO #{@database}.reverse_mapping(parameter_name, parameter_value)
          VALUES ('max_person_id', #{prev_max_person_id}), ('max_patient_program_id', #{prev_max_program_id}),
          ('max_encounter_id', #{prev_max_encounter_id}),
          ('max_obs_id', #{prev_max_obs_id}),('max_order_id', #{prev_max_order_id})
        SQL
      end
      central_execute 'Inserting reverse values to reverse_mapping table', statement
    end
    # rubocop:enable Metrics/MethodLength

    # method to check if mapping residual table exists
    def check_mapping?
      result = ActiveRecord::Base.connection.select_one <<~SQL
        SELECT count(*) AS count
        FROM information_schema.tables
        WHERE table_schema = "#{@database}"
        AND table_name = 'migration_mapping'
      SQL
      !result['count'].zero?
    end

    # def method to get all openmrs patient id from anc
    def all_anc_in_openmrs
      result = ActiveRecord::Base.connection.select_all <<~SQL
        SELECT art_patient_id FROM #{@database}.patient_migration_mapping
      SQL
      @openmrs = result.map { |variale| variale['art_patient_id'].to_i }.join(',')
    end

    # method to get max encounter_id when data was being migrated
    def prev_max_encounter_id
      min_id = ActiveRecord::Base.connection.select_one <<~SQL
        SELECT MIN(encounter_id) AS encounter_id FROM encounter WHERE patient_id IN (#{@openmrs})
      SQL
      return nil if min_id['encounter_id'].nil?

      # this means there was some data that was migrated
      result = ActiveRecord::Base.connection.select_one <<~SQL
        SELECT COALESCE(MAX(encounter_id),0) as encounter_id FROM encounter WHERE encounter_id < #{min_id['encounter_id']}
      SQL
      result['encounter_id'].to_i
    end

    # method to get max obs id when data was being migrated
    def prev_max_obs_id
      min_id = ActiveRecord::Base.connection.select_one <<~SQL
        SELECT MIN(obs_id) as obs_id FROM obs WHERE person_id IN (#{@openmrs})
      SQL
      return nil if min_id['obs_id'].nil?

      # this means there was some data that was migrated
      result = ActiveRecord::Base.connection.select_one <<~SQL
        SELECT COALESCE(MAX(obs_id),0) as obs_id FROM obs WHERE obs_id < #{min_id['obs_id'].to_i}
      SQL
      result['obs_id'].to_i
    end

    # method to get max patient id when data was being migrated
    def prev_max_program_id
      min_id = ActiveRecord::Base.connection.select_one <<~SQL
        SELECT MIN(patient_program_id) as patient_program_id FROM patient_program WHERE patient_id IN (#{@openmrs})
      SQL
      return nil if min_id['patient_program_id'].nil?

      # means some migration happen so we can get the previous value
      result = ActiveRecord::Base.connection.select_on <<~SQL
        SELECT COALESCE(MAX(patient_program_id),0) as patient_program_id FROM patient_program WHERE patient_program_id < #{min_id['patient_program_id'].to_i}
      SQL
      result['patient_program_id'].to_i
    end

    # method to get max order id when data was being migrated
    def prev_max_order_id
      min_id = ActiveRecord::Base.connection.select_one <<~SQL
        SELECT MIN(order_id) as order_id FROM orders WHERE patient_id IN (#{@openmrs})
      SQL
      return nil if min_id['order_id'].nil?

      # means some migration happen so we can get the previous value
      result = ActiveRecord::Base.connection.select_one <<~SQL
        SELECT COALESCE(MAX(order_id),0) as order_id FROM orders WHERE order_id < #{mid['order_id'].to_i}
      SQL
      result['order_id'].to_i
    end

    # method to get max order id when data was being migrated
    def prev_max_person_id
      min_id = ActiveRecord::Base.connection.select_one <<~SQL
        SELECT MIN(person_id) as person_id FROM person WHERE creator IN (#{@users})
      SQL
      return nil if min_id['person_id'].nil?

      # means some migration happen so we can get the previous value
      result = ActiveRecord::Base.connection.select_one <<~SQL
        SELECT COALESCE(MAX(person_id),0) as person_id FROM person WHERE person_id < #{mid['person_id'].to_i}
      SQL
      result['person_id'].to_i
    end

    # method to remove drug orders
    def remove_drug_orders
      condition = <<~SQL
        WHERE order_id IN (SELECT order_id FROM orders WHERE patient_id NOT IN (#{@remove}))
      SQL
      central_hub 'drug_order', condition
    end

    # method to remove orders
    def remove_orders
      central_hub 'orders', "WHERE patient_id NOT IN (#{@remove})"
    end

    # method to remove observations
    def remove_obs
      central_hub 'obs', "WHERE person_id NOT IN (#{@remove})"
    end

    # method to remove concept proposal
    def remove_concept_proposal
      condition = "WHERE encounter_id NOT IN (SELECT encounter_id FROM encounter WHERE patient_id IN (#{@remove}))"
      central_hub 'concept_proposal', condition
    end

    # method to remove encounters
    def remove_encounters
      central_hub 'encounter', "WHERE patient_id NOT IN (#{@remove})"
    end

    # method to remove patient state
    def remove_patient_state
      condition = <<~SQL
        WHERE patient_program_id NOT IN(SELECT patient_program_id FROM patient_program WHERE patient_id IN (#{@remove}))
      SQL
      central_hub 'patient_state', condition
    end

    # method to remove patient program records
    def remove_patient_program
      central_hub 'patient_program', "WHERE patient_id NOT IN (#{@remove})"
    end

    # method to remove patient identifier records
    def remove_patient_identifier
      central_hub 'patient_identifier', "WHERE patient_id NOT IN (#{@remove})"
    end

    # method to remove patients
    def remove_patient
      central_hub 'patient', "WHERE patient_id NOT IN (#{@remove})"
    end

    # method to remove person attributes
    def remove_person_attribute
      central_hub 'person_attribute', "WHERE person_id NOT IN (#{@remove})"
    end

    # method to remove person address
    def remove_person_address
      central_hub 'person_address', "WHERE person_id NOT IN (#{@remove})"
    end

    # method to remove person name
    def remove_person_name
      central_hub 'person_name', "WHERE person_id NOT IN (#{@remove})"
    end

    # method to remove person records
    def remove_person
      central_hub 'person', "WHERE person_id NOT IN (#{@remove})"
    end

    # method to get patients in use
    def patient_list
      x = ActiveRecord::Base.connection.select_all <<~SQL
        SELECT patient_id FROM #{@database}.ART_patient_in_use
      SQL
      x.map { |id| id['patient_id'].to_i }.push(0).join(',')
    end

    # method to get patients in use
    def remove_list
      x = ActiveRecord::Base.connection.select_all <<~SQL
        SELECT patient_id FROM #{@database}.ART_patient_not_in_use
      SQL
      x.map { |id| id['patient_id'].to_i }.push(0).join(',')
    end

    # method to get art user ids from
    def user_list
      x = ActiveRecord::Base.connection.select_all <<~SQL
        SELECT ART_user_id FROM #{@database}.user_bak
      SQL
      x.map { |id| id['ART_user_id'].to_i }.push(0).join(',')
    end

    # method to print time when running some heavy things
    def print_time(message: 'Done', long_form: false)
      puts "#{message}: #{long_form ? Time.now : Time.now.strftime('%H:%M:%S')}"
    end

    # method to execute commands
    def central_execute(message: nil, statement: '')
      print_time message: message unless message.nil?
      ActiveRecord::Base.connection.execute statement
      print_time unless message.nil?
    end

    # rubocop:disable Metrics/MethodLength
    # method to do the needful of removing stuff
    def central_hub(table_name, condition)
      print_time message: "Removing #{table_name} records"
      ActiveRecord::Base.connection.execute <<~SQL
        DROP TABLE IF EXISTS #{table_name}_copy
      SQL
      ActiveRecord::Base.connection.execute <<~SQL
        CREATE TABLE #{table_name}_copy LIKE #{table_name}
      SQL
      ActiveRecord::Base.connection.execute <<~SQL
        INSERT INTO #{table_name}_copy SELECT * FROM #{table_name} #{condition}
      SQL
      ActiveRecord::Base.connection.execute <<~SQL
        DROP TABLE #{table_name}
      SQL
      ActiveRecord::Base.connection.execute <<~SQL
        RENAME TABLE #{table_name}_copy TO #{table_name}
      SQL
      print_time
    end
    # rubocop:enable Metrics/MethodLength
  end
  # rubocop:enable Metrics/ClassLength
end
