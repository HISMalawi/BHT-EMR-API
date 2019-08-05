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
  end
end
