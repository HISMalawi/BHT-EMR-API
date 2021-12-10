# frozen_string_literal: true

module ANCService
  # class to handle reversing of anc migrated data
  # in true sense we are just deleting the records
  class ANCReverseMigration
    def initialize(params)
      @database = params[:database]
    end

    private

    # method to map patients that are already being used
    def patient_in_use
      print_time message: 'Saving patients in use'
      ActiveRecord::Base.connection.execute <<~SQL
        DROP TABLE IF EXISTS $ANCDATABASE.ART_patient_in_use;
      SQL
      ActiveRecord::Base.connection.execute <<~SQL
        CREATE TABLE $ANCDATABASE.ART_patient_in_use AS
        SELECT p.patient_id
        FROM patient p
        INNER JOIN encounter e ON p.patient_id = e.patient_id
        WHERE p.creator IN (SELECT ART_user_id FROM $ANCDATABASE.user_bak) GROUP BY p.patient_id HAVING COUNT(*) > 1;
      SQL
      print_time
    end

    # method to map patient that not being used
    def patient_not_in_use
      print_time message: 'Saving patients not in use'
      ActiveRecord::Base.connection.execute <<~SQL
        DROP TABLE IF EXISTS $ANCDATABASE.ART_patient_identifier_in_use
      SQL
      ActiveRecord::Base.connection.execute <<~SQL
        CREATE TABLE $ANCDATABASE.ART_patient_identifier_in_use AS
        SELECT e.patient_id, e.identifier
        FROM $DATABASE.patient_identifier e
        WHERE e.patient_id IN (SELECT p.patient_id FROM $ANCDATABASE.ART_patient_in_use p)
      SQL
      ActiveRecord::Base.connection.execute <<~SQL
        ALTER TABLE $ANCDATABASE.ART_patient_identifier_in_use ADD INDEX identifier_in_use (patient_id);
      SQL
      print_time
    end

    # method to map all patients
    def patient_mapping
      print_time message: 'Saving patient mapping'
      ActiveRecord::Base.connection.execute <<~SQL
        DROP TABLE IF EXISTS $ANCDATABASE.patient_migration_mapping
      SQL
      ActiveRecord::Base.connection.execute <<~SQL
        CREATE TABLE $ANCDATABASE.patient_migration_mapping
        SELECT DISTINCT(anc.patient_id) AS anc_patient_id, art.patient_id AS art_patient_id
        FROM $ANCDATABASE.patient_identifier anc
        JOIN $DATABASE.patient_identifier art ON anc.identifier = art.identifier
        JOIN $ANCDATABASE.user_bak bak ON anc.creator = bak.ANC_user_id
        WHERE art.creator = bak.ART_user_id
        AND art.date_created = anc.date_created
      SQL
      ActiveRecord::Base.connection.execute <<~SQL
        ALTER TABLE $ANCDATABASE.patient_migration_mapping add primary key (anc_patient_id)
      SQL
      print_time
    end

    # method to remove drug orders
    def remove_drug_orders
      print_time message: 'Removing drug orders'
      ActiveRecord::Base.connection.execute <<~SQL
        DELETE FROM $DATABASE.drug_order WHERE order_id IN (SELECT order_id FROM $DATABASE.orders WHERE creator IN (SELECT ART_user_id FROM $ANCDATABASE.user_bak) AND patient_id NOT IN (SELECT patient_id FROM $ANCDATABASE.ART_patient_in_use))
      SQL
      print_time
    end

    # method to remove orders
    def remove_orders
      print_time message: 'Removing orders'
      ActiceRecord::Base.connection.execute <<~SQL
        DELETE FROM $DATABASE.orders WHERE creator IN (SELECT ART_user_id FROM $ANCDATABASE.user_bak) AND patient_id NOT IN (SELECT patient_id FROM $ANCDATABASE.ART_patient_in_use)
      SQL
      print_time
    end

    # method to remove observations
    def remove_obs
      print_time message: 'Removing obs'
      ActiveRecord::Base.connection.execute <<~SQL
        DELETE FROM $DATABASE.obs WHERE creator IN (SELECT ART_user_id FROM $ANCDATABASE.user_bak) AND person_id NOT IN (SELECT patient_id FROM $ANCDATABASE.ART_patient_in_use)
      SQL
      print_time
    end

    # method to remove encounters
    def remove_encounters
      print_time message: 'Removing encounters'
      ActiveRecord::Base.connection.execute <<~SQL
        DELETE FROM $DATABASE.encounter WHERE creator IN (SELECT ART_user_id FROM $ANCDATABASE.user_bak) AND patient_id NOT IN (SELECT patient_id FROM $ANCDATABASE.ART_patient_in_use)
      SQL
    end

    # method to remove patient state
    def remove_patient_state
      print_time message: 'Removing patient state'
      ActiveRecord::Base.connection.execute <<~SQL
        DELETE FROM $DATABASE.patient_state WHERE creator IN (SELECT ART_user_id FROM $ANCDATABASE.user_bak) AND patient_program_id NOT IN(SELECT patient_program_id FROM $DATABASE.patient_program WHERE patient_id IN (SELECT patient_id FROM $ANCDATABASE.ART_patient_in_use))
      SQL
      print_time
    end

    # method to remove patient program records
    def remove_pateint_program
      print_time message: 'Removeing patient program'
      ActiveRecord::Base.connection.execute <<~SQL
        DELETE FROM $DATABASE.patient_program WHERE creator IN (SELECT ART_user_id FROM $ANCDATABASE.user_bak) AND patient_id NOT IN (SELECT patient_id FROM $ANCDATABASE.ART_patient_in_use)
      SQL
      print_time
    end

    # method to remove patient identifier records
    def remove_patient_identifier
      print_time message: 'Removing patient identifier'
      ActiveRecord::Base.connection.execute <<~SQL
        DELETE FROM $DATABASE.patient_identifier WHERE creator IN (SELECT ART_user_id FROM $ANCDATABASE.user_bak) AND patient_id NOT IN (SELECT patient_id FROM $ANCDATABASE.ART_patient_in_use)
      SQL
      print_time
    end

    # method to remove patients
    def remove_patient
      print_time message: 'Removing patients'
      ActiveRecord::Base.connection.execute <<~SQL
        DELETE FROM $DATABASE.patient WHERE creator IN (SELECT ART_user_id FROM $ANCDATABASE.user_bak) AND patient_id NOT IN (SELECT patient_id FROM $ANCDATABASE.ART_patient_in_use)
      SQL
      print_time
    end

    # method to remove person attributes
    def remove_person_attribute
      print_time message: 'Removing person attributes'
      ActiveRecord::Base.connection.execute <<~SQL
        DELETE FROM $DATABASE.person_attribute WHERE creator IN (SELECT ART_user_id FROM $ANCDATABASE.user_bak) AND person_id NOT IN (SELECT patient_id FROM $ANCDATABASE.ART_patient_in_use)
      SQL
      print_time
    end

    # method to remove person address
    def remove_person_address
      print_time message: 'Removing person address'
      ActiveRecord::Base.connection.execute <<~SQL
        DELETE FROM $DATABASE.person_address WHERE creator IN (SELECT ART_user_id FROM $ANCDATABASE.user_bak) AND person_id NOT IN (SELECT patient_id FROM $ANCDATABASE.ART_patient_in_use)
      SQL
      print_time
    end

    # method to remove person name
    def remove_person_name
      print_time message: 'Removing person name'
      ActiveRecord::Base.connection.execute <<~SQL
        DELETE FROM $DATABASE.person_name WHERE creator IN (SELECT ART_user_id FROM $ANCDATABASE.user_bak) AND person_id NOT IN (SELECT patient_id FROM $ANCDATABASE.ART_patient_in_use)
      SQL
      print_time
    end

    # method to remove users records
    def remove_user
      print_time message: 'Removing users'
      ActiveRecord::Base.connection.execute <<~SQL
        DELETE FROM $DATABASE.users WHERE user_id IN (SELECT ART_user_id FROM $ANCDATABASE.user_bak) AND user_id NOT IN (SELECT DISTINCT(creator) FROM $DATABASE.patient)
      SQL
      print_time
    end

    # method to remove person records
    def remove_person
      print_time message: 'Remove person'
      ActiveRecord::Base.connection.execute <<~SQL
        DELETE FROM $DATABASE.person WHERE creator IN (SELECT ART_user_id FROM $ANCDATABASE.user_bak) AND person_id NOT IN (SELECT patient_id FROM $ANCDATABASE.ART_patient_in_use)
      SQL
    end

    # method to print start time
    def print_time(message: 'Done', long_form: false)
      puts "#{message}: #{long_form ? Time.now : Time.now.strftime('%H:%M:%S')}"
    end
  end
end
