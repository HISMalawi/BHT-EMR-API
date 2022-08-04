class OrderSet < RetirableRecord
  self.table_name = :order_set
  self.primary_key = :order_set_id
end
