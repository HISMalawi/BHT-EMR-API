# frozen_string_literal: true

class ConceptName < VoidableRecord
  self.table_name = :concept_name
  self.primary_key = :concept_name_id

  has_many :concept_name_tag_maps # no default scope
  has_many :tags, through: :concept_name_tag_maps, class_name: 'ConceptNameTag'

  belongs_to :concept

  scope :tagged, ->(tags) { tags.blank? ? {} : joins(:tags).where('concept_name_tag.tag IN (?)', Array(tags)) }
  scope :typed, ->(tags) { tags.blank? ? {} : where('concept_name_type IN (?)', Array(tags)) }
end
