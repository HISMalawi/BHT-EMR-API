# frozen_string_literal: true

# Model: VisitAttributeType
class VisitAttributeType < RetirableRecord
    self.table_name = 'visit_attribute_type'
    self.primary_key = 'visit_attribute_type_id'
  
    has_many :visit_attribute, foreign_key: attribute_type_id
    validates :name, :min_occurs, presence: true
  end