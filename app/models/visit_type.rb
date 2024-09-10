class VisitType < RetirableRecord
    self.table_name = 'visit_type'
    self.primary_key = 'visit_type_id'

    def self.find_by_uuid(uuid)
      find_by(uuid: uuid)
    end
  
    has_many :visits, foreign_key: :visit_type_id
  
    validates :name, presence: true
  end

  