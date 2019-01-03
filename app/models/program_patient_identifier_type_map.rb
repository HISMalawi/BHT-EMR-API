# frozen_string_literal: true

class ProgramPatientIdentifierTypeMap < ApplicationRecord
  self.table_name = 'program_patient_identifier_type_map'
  self.primary_key = 'program_patient_identifier_type_map_id'

  belongs_to :program
  belongs_to :patient_identifier_type
end
