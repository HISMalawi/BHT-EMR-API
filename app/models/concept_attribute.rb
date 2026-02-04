class ConceptAttribute < VoidableRecord
  self.table_name = :concept_attribute
  self.primary_key = :concept_attribute_id

  include Auditable
  include Voidable

  belongs_to :concept
  belongs_to :attribute_type, class_name: 'ConceptAttributeType', foreign_key: :attribute_type_id
end