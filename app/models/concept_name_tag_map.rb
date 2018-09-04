# frozen_string_literal: true

class ConceptNameTagMap < VoidableRecord
  self.table_name = :concept_name_tag_map
  self.primary_key = :concept_name_tag_map_id

  belongs_to :tag, foreign_key: :concept_name_tag_id, class_name: 'ConceptNameTag'
  belongs_to :concept_name_tag
  belongs_to :concept_name
end
