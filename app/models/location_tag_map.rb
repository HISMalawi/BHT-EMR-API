# frozen_string_literal: true

class LocationTagMap < ApplicationRecord
  self.table_name = :location_tag_map
  self.primary_key = %i[location_tag_id location_id]
end
