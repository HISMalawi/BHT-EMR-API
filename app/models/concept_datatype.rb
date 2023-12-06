class ConceptDatatype < RetirableRecord
  self.table_name = :concept_datatype
  self.primary_key = :concept_datatype_id

  has_many :concepts, class_name: 'Concept', foreign_key: :datatype_id
end
