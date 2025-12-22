class ConceptDescription < ApplicationRecord
  self.table_name = 'concept_description'
  self.primary_key = 'concept_description_id'

  belongs_to :concept, foreign_key: :concept_id
end
