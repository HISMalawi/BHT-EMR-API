class VisitAttribute < VoidableRecord
  self.table_name = :visit_attribute
  self.primary_key = :visit_attribute_id

  belongs_to :visit
  belongs_to :attribute_type
  belongs_to :creator, class_name: 'User', foreign_key: :creator
end
