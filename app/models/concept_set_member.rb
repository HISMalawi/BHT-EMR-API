class ConceptSetMember < ApplicationRecord
  self.table_name = 'concept_set_member'
  self.primary_key = 'concept_set_member_id'

  belongs_to :concept, foreign_key: :concept_id
  belongs_to :concept_set, class_name: 'Concept', foreign_key: :concept_set_id
end
