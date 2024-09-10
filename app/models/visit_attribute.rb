class VisitAttribute < VoidableRecord
    self.table_name = 'visit_attribute'
    self.primary_key = 'visit_attribute_id'
    
    belongs_to :visit
    
    validates :visit, :value_reference, presence: true
  end