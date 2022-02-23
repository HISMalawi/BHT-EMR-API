# frozen_string_literal:true

module ANCService
  # class that will map the users in the system
  class ANCMappingMigration
    def initialize(anc_database, confidence)
      @database = anc_database
      @confidence = confidence
      @file = File.new("migration_scores_#{Time.now.strftime('%Y%m%d')}.csv", 'w+')
    end

    # method to loop and create linkage between anc and openmrs(art) database
    def map_linkage_between_anc_and_openmrs
      create_mapped
      create_unmapped
      @file.puts('ANC Patient,ANC Identifier,ART Patient,ART Identifier,Score')
      anc = ActiveRecord::Base.connection.select_all <<~SQL
        select identifier, patient_id
        from  #{@database}.patient_identifier
        where patient_identifier.identifier_type = 3
        and patient_identifier.voided = 0
      SQL
      print_time message: 'Mapping Patients'
      anc.each do |identifier|
        openmrs = ActiveRecord::Base.connection.select_all "SELECT patient_id, identifier, void_reason FROM patient_identifier WHERE identifier = '#{identifier['identifier']}'"
        result = check_match(identifier, openmrs)
        if result.blank?
          unmapped_patients(identifier['patient_id'],
                            identifier['identifier'])
        else
          mapped_patients(result, identifier['identifier'])
        end
      end
      @file.close
      print_time
    end

    private

    # method saved mapped patients
    def mapped_patients(map, identifier)
      statement = <<~SQL
        INSERT INTO #{@database}.mapped_patients(anc_patient_id, art_patient_id, anc_identifier, art_identifier, reason)
        VALUES (#{map.keys[0]}, #{map.values[0]}, "#{identifier}", '#{map.values[1]}', '#{map.values[2]}')
      SQL
      central_execute statement
    end

    # method to save patients without any linkage
    def unmapped_patients(patient_id, identifier)
      statement = <<~SQL
        INSERT INTO #{@database}.unmapped_patients(anc_patient_id, identifier)
        VALUES (#{patient_id}, '#{identifier}')
      SQL
      central_execute statement
    end

    # method to check dob
    def check_match(anc, openmrs)
      if openmrs.blank?
        write_to_file(anc['patient_id'], anc['identifier'], '', '', 0)
        return nil
      end

      record = nil
      openmrs.each do |identifier|
        @score = 0
        patient = Patient.find_by(patient_id: identifier['patient_id'])
        next if patient.blank?

        ANCDetails.fetch_dob(@database, anc['patient_id']) == patient.person.birthdate ? @score += 5 : nil
        anc_name = ANCDetails.fetch_name(@database, anc['patient_id'])
        anc_name['given_name'] == patient.person.names[0].given_name ? @score += 5 : nil
        anc_name['family_name'] == patient.person.names[0].family_name ? @score += 5 : nil
        ANCDetails.fetch_gender(@database, anc['patient_id']) == patient.person.gender ? @score += 5 : nil
        check_address(ANCDetails.fetch_address(@data, anc['patient_id']), patient.person.addresses[0])
        check_attribute(anc['patient_id'], patient)
        local_score = (@score * 100) / 45.0
        percentage = local_score >= @confidence
        write_to_file(anc['patient_id'], anc['identifier'], patient.id,
                      patient.patient_identifiers.find_by(identifier_type: 3).identifier,
                      local_score)
        if percentage
          record = { anc => patient.id,
                     'identifier' => patient.patient_identifiers.find_by(identifier_type: 3).identifier,
                     'reason' => identifier['void_reason'] }
        end
        break if percentage
      end
      record
    end

    # method to write the scores to a csv file
    def write_to_file(anc_patient, anc_identifier, art_patient, art_identifier, score)
      @file.puts("#{anc_patient},#{anc_identifier},#{art_patient},#{art_identifier},#{score}")
    end

    # method to check person attributes
    def check_attribute(anc, openmrs)
      @score += 2 if attribute_checker(anc, openmrs, 13)
      @score += 3 if attribute_checker(anc, openmrs, 12)
      @score += 5 if attribute_checker(anc, openmrs, 3)
    end

    # method to just check the different attribute types of a patient
    def attribute_checker(anc, openmrs, type)
      record = ANCDetails.fetch_attribute(@database, anc, type)
      return false if record.blank?

      record == openmrs.person.person_attributes.find_by(person_attribute_type_id: type)&.value
    end

    # method to check addresses
    def check_address(anc, openmrs)
      return if anc.blank? || openmrs.blank?

      @score += 4 if anc['address2'] == openmrs['address2']
      @score += 4 if anc['county_district'] == openmrs['county_district']
      @score += 4 if anc['neighborhood_cell'] == openmrs['neighborhood_cell']
      @score += 1 if anc['state_province'] == openmrs['state_province']
      @score += 1 if anc['city_village'] == openmrs['city_village']
      @score += 1 if anc['address1'] == openmrs['address1']
    end

    # method to create unmapped table
    def create_mapped
      statements = <<~SQL
        DROP TABLE IF EXISTS #{@database}.mapped_patients;
        CREATE TABLE #{@database}.mapped_patients (anc_patient_id int NOT NULL, art_patient_id int NOT NULL,anc_identifier varchar(60) NOT NULL, art_identifier varchar(60) NOT NULL, reason varchar(255) NULL,PRIMARY KEY (anc_patient_id))
      SQL
      print_time message: 'Creating a table of patients with linkage'
      statements.split(';').each { |value| central_hub message: nil, query: value.strip }
      print_time
    end

    # method to create unmapped table
    def create_unmapped
      statements = <<~SQL
        DROP TABLE IF EXISTS #{@database}.unmapped_patients;
        CREATE TABLE #{@database}.unmapped_patients (anc_patient_id int NOT NULL,identifier varchar(60) NOT NULL,PRIMARY KEY (anc_patient_id))
      SQL
      print_time message: 'Creating a table of patients without any linkage'
      statements.split(';').each { |value| central_hub message: nil, query: value.strip }
      print_time
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
    end
  end
end
