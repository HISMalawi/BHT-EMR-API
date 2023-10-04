# frozen_string_literal: true

class Regimen < RetirableRecord
  self.table_name = :regimen
  self.primary_key = :regimen_id

  belongs_to :concept, optional: true
  belongs_to :program
  has_many :regimen_drug_orders

  scope :program, ->(program_id) { where(program_id:) }
  scope :criteria, lambda { |weight|
    where('min_weight <= ? AND max_weight > ?', weight, weight)
  }
end
