class LocationAttribute < VoidableRecord
  belongs_to :location
  belongs_to :location_attribute_types
  belongs_to :creator, class_name: 'User', foreign_key: :creator
end
