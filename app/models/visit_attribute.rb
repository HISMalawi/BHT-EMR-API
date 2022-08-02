class VisitAttribute < VoidableRecord
  belongs_to :visit
  belongs_to :attribute_type
  belongs_to :value_reference, polymorphic: true
  belongs_to :creator, class_name: 'User', foreign_key: :creator
end
