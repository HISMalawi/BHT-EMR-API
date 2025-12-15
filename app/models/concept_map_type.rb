class ConceptMapType < RetirableRecord
  self.table_name = 'concept_map_type'
  self.primary_key = 'concept_map_type_id'

  has_many :concept_maps, foreign_key: :concept_map_type_id
end
