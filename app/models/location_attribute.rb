# app/models/location_attribute.rb
class LocationAttribute < ApplicationRecord
  self.table_name = 'location_attribute'
  self.primary_key = 'location_attribute_id'

  # Define the association to the Location model
  belongs_to :location, foreign_key: 'location_id'

end