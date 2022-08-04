class OrderFrequency < RetirableRecord
  self.table_name = :order_frequency
  self.primary_key = :order_frequency_id
  belongs_to :concept
end