# frozen_string_literal: true

module PatientIdentifierService
  class << self
    ##
    # Finds all duplicate identifiers of a given type.
    #
    # Returns an array of (identifier, count) pairs where the count is the
    # number of duplicates found.
    #
    # @param {PatientIdentifierType} identifier_type
    # @returns {Array<Array<string, integer>>}
    def find_duplicates(identifier_type)
      pid_type_id = ActiveRecord::Base.connection.quote(identifier_type.id)

      rows = ActiveRecord::Base.connection.select_all(
        <<~SQL
          SELECT identifier, count(identifier) AS `count` FROM patient_identifier
          WHERE voided = 0 AND identifier_type = #{pid_type_id}
          GROUP BY identifier HAVING count(identifier) > 1
        SQL
      )

      rows.collect { |row| { count: row['count'], identifier: row['identifier'] } }
    end

    def find_multiples(identifier_type)
      ActiveRecord::Base.connection.select_all <<~SQL
        SELECT p.person_id patient_id, n.given_name, n.family_name, p.gender, p.birthdate, MAX(i.identifier) latest_identifier, COUNT(i.identifier) identifiers, GROUP_CONCAT(i.identifier) mutliple_identifiers
        FROM person p
        INNER JOIN patient_identifier i ON i.patient_id = p.person_id AND i.identifier_type = #{identifier_type.id} AND i.voided = 0
        LEFT JOIN person_name n ON n.person_id = p.person_id AND n.voided = 0
        WHERE p.voided = 0
        GROUP BY p.person_id HAVING COUNT(i.identifier) > 1
        ORDER BY n.date_created DESC
      SQL
    end

    def create(params)
      identifier = PatientIdentifier.find_by(identifier_type: params[:identifier_type],
                                             identifier: params[:identifier])
      if identifier
        return identifier if identifier.patient_id == params[:patient_id]

        raise InvalidParameterError, 'Identifier already assigned to another patient'
      end

      identifier = PatientIdentifier.find_by(patient_id: params[:patient_id],
                                             identifier_type: params[:identifier_type])
      identifier&.void("Updated to #{params[:identifier]} by #{User.current.username}")

      identifier = PatientIdentifier.new(params)
      identifier[:location_id] = Location.current.location_id
      identifier.save

      identifier
    end
  end
end
