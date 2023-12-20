# frozen_string_literal: true

module PatientIdentifierService
  class << self
    def find_duplicates(identifier_type)
      pid_type_id = ActiveRecord::Base.connection.quote(identifier_type.id)
      query = <<~SQL
        SELECT identifier, COUNT(identifier) AS `count`
        FROM patient_identifier
        WHERE voided = 0 AND identifier_type = #{pid_type_id}
        GROUP BY identifier
        HAVING COUNT(identifier) > 1
      SQL

      rows = ActiveRecord::Base.connection.select_all(query)
      rows.map { |row| { count: row['count'], identifier: row['identifier'] } }
    end

    def find_multiples(identifier_type)
      data = fetch_multiple_identifiers_data(identifier_type.id)
      data.map do |row|
        build_patient_data(row)
      end
    end

    def create(params)
      validate_identifier(params)
      void_existing_identifier(params)
      create_new_identifier(params)
    end

    def swap_active_number(primary_patient_id:, secondary_patient_id:, identifier:)
      validate_identifier_assignment(identifier)
      void_filing_numbers(primary_patient_id, secondary_patient_id)
      switch_active_and_archive_numbers(primary_patient_id, secondary_patient_id, identifier)
    end

    private

    def identifier_already_assigned_today?(identifier:)
      today = Time.now.beginning_of_day
      PatientIdentifier.where(identifier: identifier).where('date_created >= ?', today).exists?
    end

    def fetch_multiple_identifiers_data(identifier_type_id)
      query = <<~SQL
        SELECT p.person_id patient_id, n.given_name, n.family_name, p.gender, p.birthdate,
               MAX(i.identifier) latest_identifier, COUNT(i.identifier) identifiers,
               GROUP_CONCAT(i.identifier) mutliple_identifiers
        FROM person p
        INNER JOIN patient_identifier i ON i.patient_id = p.person_id AND i.identifier_type = #{identifier_type_id} AND i.voided = 0
        LEFT JOIN person_name n ON n.person_id = p.person_id AND n.voided = 0
        WHERE p.voided = 0
        GROUP BY p.person_id HAVING COUNT(i.identifier) > 1
        ORDER BY n.date_created DESC
      SQL

      ActiveRecord::Base.connection.select_all(query)
    end

    def build_patient_data(row)
      {
        patient_id: row['patient_id'],
        given_name: row['given_name'],
        family_name: row['family_name'],
        gender: row['gender'],
        birthdate: row['birthdate'],
        latest_identifier: row['latest_identifier'],
        identifiers: PatientIdentifier.where(identifier: row['mutliple_identifiers'].split(','), patient_id: row['patient_id'])
      }
    end

    def validate_identifier(params)
      identifier = PatientIdentifier.find_by(identifier_type: params[:identifier_type], identifier: params[:identifier])
      return unless identifier && identifier.patient_id != params[:patient_id]

      raise InvalidParameterError, 'Identifier already assigned to another patient'
    end

    def void_existing_identifier(params)
      patient_id = params[:patient_id]
      identifier_type = params[:identifier_type]
      identifier = PatientIdentifier.find_by(patient_id: patient_id, identifier_type: identifier_type)
      identifier&.void("Updated to #{params[:identifier]} by #{User.current.username}")
    end

    def create_new_identifier(params)
      identifier = PatientIdentifier.new(params)
      identifier[:location_id] = Location.current.location_id
      identifier.save
      identifier
    end

    def validate_identifier_assignment(identifier)
      return unless identifier_already_assigned_today?(identifier: identifier)

      raise InvalidParameterError, 'Identifier already assigned to another patient'
    end

    def void_filing_numbers(primary_patient_id, secondary_patient_id)
      void_identifier_type('Filing number', primary_patient_id, secondary_patient_id)
      void_identifier_type('Archived filing number', primary_patient_id, secondary_patient_id)
    end

    def void_identifier_type(identifier_type_name, *patient_ids)
      itype = PatientIdentifierType.find_by(name: identifier_type_name)
      patient_ids.each do |id|
        PatientIdentifier.where(identifier_type: itype.id, patient_id: id).each do |i|
          i.void("Voided by #{User.current.username}")
        end
      end
    end

    def switch_active_and_archive_numbers(primary_patient_id, secondary_patient_id, identifier)
      active_identifier = 'Filing number'
      dormant_identifier = 'Archived filing number'

      void_identifier_type(active_identifier, primary_patient_id, secondary_patient_id)

      archive_identifier = FilingNumberService.new.find_available_filing_number(dormant_identifier)
      create_patient_identifier(secondary_patient_id, archive_identifier, dormant_identifier)
      create_patient_identifier(primary_patient_id, identifier, active_identifier)
      {
        active_number: identifier,
        primary_patient_id: primary_patient_id,
        secondary_patient_id: secondary_patient_id,
        dormant_number: archive_identifier
      }
    end

    def create_patient_identifier(patient_id, identifier, identifier_type_name)
      itype = PatientIdentifierType.find_by(name: identifier_type_name)
      PatientIdentifier.create(patient_id: patient_id, identifier_type: itype.id, identifier: identifier, location_id: Location.current.id)
    end
  end
end
