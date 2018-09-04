# frozen_string_literal: true

class ConceptAnswer < ApplicationRecord
  self.table_name = :concept_answer
  self.primary_key = :concept_answer_id

  belongs_to :answer, class_name: 'Concept', foreign_key: 'answer_concept'
  belongs_to :drug, class_name: 'Drug', foreign_key: 'answer_drug'
  belongs_to :concept, class_name: 'Concept', foreign_key: 'concept_id'
end
