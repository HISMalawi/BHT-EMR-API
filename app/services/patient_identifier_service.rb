# frozen_string_literal: true

module PatientIdentifierService
  class << self
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
