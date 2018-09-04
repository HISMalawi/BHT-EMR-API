class ConceptMap < ApplicationRecord
  self.table_name = :concept_map
  self.primary_key = :concept_map_id

  belongs_to :concept, :conditions => {:retired => 0}
  belongs_to :concept_source, :class_name => 'ConceptSource', :foreign_key => :source, :conditions => {:voided => 0}
end

