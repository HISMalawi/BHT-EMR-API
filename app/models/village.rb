class Village < RetirableRecord
  self.table_name  = 'village'
  self.primary_key = 'village_id'

  belongs_to :traditional_authority
end
