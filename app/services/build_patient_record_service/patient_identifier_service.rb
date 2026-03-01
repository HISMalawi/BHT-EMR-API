# frozen_string_literal: true
module BuildPatientRecordService
  module PatientIdentifierService
    extend self
    def patient_identifier(identifiers, identifier_type_id)
      begin
        if identifiers
          identifiers.patient_identifiers
                    .select { |identifier| identifier.identifier_type == identifier_type_id }
                    .map(&:identifier)
                    .join(', ')
        else
          ''
        end
      rescue StandardError => e
        Rails.logger.error("Error getting patient identifier for type #{identifier_type_id}: #{e.message}")
        ''
      end
    end
  end
end
