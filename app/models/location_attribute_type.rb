# frozen_string_literal: true

class LocationAttributeType < ApplicationRecord
  self.table_name = 'location_attribute_type'
  self.primary_key = 'location_attribute_type_id'

  has_many :location_attributes, foreign_key: 'attribute_type_id'
end
