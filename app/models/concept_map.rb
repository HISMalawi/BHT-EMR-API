# frozen_string_literal: true

class ConceptMap < ApplicationRecord
  self.table_name = :concept_map
  self.primary_key = :concept_map_id

  belongs_to :concept
  belongs_to :concept_source, class_name: 'ConceptSource', foreign_key: :concept_source_id
  belongs_to :concept_map_type, class_name: 'ConceptMapType', foreign_key: :concept_map_type_id
end
