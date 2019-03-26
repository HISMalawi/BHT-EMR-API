class Region < ApplicationRecord
  self.table_name = 'region'
  self.primary_key = 'region_id'

  has_many :districts, foreign_key: :region_id
end
