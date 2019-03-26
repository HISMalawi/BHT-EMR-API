class LocationTagMap < ApplicationRecord
  self.table_name = :location_tag_map
  self.primary_keys = %i[location_tag_id location_id]
end
