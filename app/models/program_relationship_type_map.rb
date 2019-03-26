# frozen_string_literal: true

class ProgramRelationshipTypeMap < ApplicationRecord
  self.table_name = 'program_relationship_type_map'
  self.primary_key = 'program_relationship_type_map_id'

  belongs_to :program
  belongs_to :relationship_type
end
