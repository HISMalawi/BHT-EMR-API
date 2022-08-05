class Visit < VoidableRecord
  self.table_name = :visit
  self.primary_key = :visit_id
  belongs_to :patient
  belongs_to :visit_type
  belongs_to :location
  belongs_to :creator, class_name: 'User', foreign_key: :creator
end
