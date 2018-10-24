# frozen_string_literal: true

class RelationshipType < RetirableRecord
  self.table_name = :relationship_type
  self.primary_key = :relationship_type_id

  default_scope { order('weight DESC') }

  has_many :relationships
end
