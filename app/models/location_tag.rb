# frozen_string_literal: true

class LocationTag < RetirableRecord
  self.table_name = :location_tag
  self.primary_key = :location_tag_id

  has_many :location_tag_map, foreign_key: :location_tag_id
end
