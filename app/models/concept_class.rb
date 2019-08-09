class ConceptClass < RetirableRecord
  self.table_name = :concept_class
  self.primary_key = :concept_class_id

  has_many :concepts, class_name: 'Concept', foreign_key: 'class_id'
end
