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
      rescue => exception
        puts exception.message[0..1000]
        #puts exception.backtrace
      end
      print_time message: 'Finished migration reversal script', long_form: true
    end
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/AbcSize

    private

    # rubocop:disable Metrics/MethodLength
    # method to map patients that are already being used
    def patient_in_use
      print_time message: 'Saving patients in use'
      ActiveRecord::Base.connection.execute <<~SQL
        DROP TABLE IF EXISTS #{@database}.ART_patient_in_use;
      SQL
      ActiveRecord::Base.connection.execute <<~SQL
        CREATE TABLE #{@database}.ART_patient_in_use AS
        SELECT p.patient_id
        FROM patient p
        INNER JOIN encounter e ON p.patient_id = e.patient_id
        WHERE p.creator IN (#{@users})
        AND e.date_created >= DATE('#{@date}')
        GROUP BY p.patient_id HAVING COUNT(*) > 0;
      SQL
      print_time
    end
    # rubocop:enable Metrics/MethodLength

    # rubocop:disable Metrics/MethodLength
    # method to map patient that not being used
    def patient_identifier_in_use
      print_time message: 'Saving patients identifiers in use'
      ActiveRecord::Base.connection.execute <<~SQL
        DROP TABLE IF EXISTS #{@database}.ART_patient_identifier_in_use
      SQL
      ActiveRecord::Base.connection.execute <<~SQL
        CREATE TABLE #{@database}.ART_patient_identifier_in_use AS
        SELECT e.patient_id, e.identifier
        FROM patient_identifier e
        WHERE e.patient_id IN (#{@patients})
      SQL
      ActiveRecord::Base.connection.execute <<~SQL
        ALTER TABLE #{@database}.ART_patient_identifier_in_use ADD INDEX identifier_in_use (patient_id);
      SQL
      print_time
    end
    # rubocop:enable Metrics/MethodLength

    # rubocop:disable Metrics/MethodLength
    # method to get identifiers for patients not in use
    def patient_identifier_not_in_use
      print_time message: 'Saving patients identifiers not in use'
      ActiveRecord::Base.connection.execute <<~SQL
        DROP TABLE IF EXISTS #{@database}.ART_patient_identifier_not_in_use
      SQL
      ActiveRecord::Base.connection.execute <<~SQL
        CREATE TABLE #{@database}.ART_patient_identifier_not_in_use AS
        SELECT e.patient_id, e.identifier
        FROM patient_identifier e
        WHERE e.patient_id IN (SELECT p.patient_id FROM #{@database}.ART_patient_not_in_use p)
      SQL
      ActiveRecord::Base.connection.execute <<~SQL
        ALTER TABLE #{@database}.ART_patient_identifier_not_in_use ADD INDEX identifier_not_in_use (patient_id);
      SQL
      print_time
    end
    # rubocop:enable Metrics/MethodLength

    # rubocop:disable Metrics/MethodLength
    # method to map patient that not being used
    def patient_not_in_use
      print_time message: 'Saving patients not in use'
      ActiveRecord::Base.connection.execute <<~SQL
        DROP TABLE IF EXISTS #{@database}.ART_patient_not_in_use;
      SQL
      ActiveRecord::Base.connection.execute <<~SQL
        CREATE TABLE #{@database}.ART_patient_not_in_use AS
        SELECT p.patient_id
        FROM patient p
        WHERE p.creator IN (#{@users})
        AND p.patient_id NOT IN (#{@patients})
      SQL
      print_time
    end
    # rubocop:enable Metrics/MethodLength

    # rubocop:disable Metrics/MethodLength
    # method to map all patients
    def patient_mapping
      print_time message: 'Saving patient mapping'
      ActiveRecord::Base.connection.execute <<~SQL
        DROP TABLE IF EXISTS #{@database}.patient_migration_mapping
      SQL
      ActiveRecord::Base.connection.execute <<~SQL
        CREATE TABLE #{@database}.patient_migration_mapping
        SELECT DISTINCT(anc.patient_id) AS anc_patient_id, art.patient_id AS art_patient_id
        FROM #{@database}.patient_identifier anc
        JOIN patient_identifier art ON anc.identifier = art.identifier
        JOIN #{@database}.user_bak bak ON anc.creator = bak.ANC_user_id
        WHERE art.creator = bak.ART_user_id
        AND art.date_created = anc.date_created
      SQL
      ActiveRecord::Base.connection.execute <<~SQL
        ALTER TABLE #{@database}.patient_migration_mapping add primary key (anc_patient_id)
      SQL
      print_time
    end
    # rubocop:enable Metrics/MethodLength

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
