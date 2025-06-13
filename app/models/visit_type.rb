# frozen_string_literal: true

class VisitType < RetirableRecord
  self.table_name = 'visit_type'
  self.primary_key = 'visit_type_id'

  has_many :visits, foreign_key: :visit_type_id

  validates :name, presence: true
end
