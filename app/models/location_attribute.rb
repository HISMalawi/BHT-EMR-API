class LocationAttribute < VoidableRecord
  self.table_name = :location_attribute
  self.primary_key = :location_attribute_id
  belongs_to :location
  belongs_to :location_attribute_types
  belongs_to :creator, class_name: 'User', foreign_key: :creator
end
