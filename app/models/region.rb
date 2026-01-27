# frozen_string_literal: true

class Region < RetirableRecord
  self.table_name = :location
  self.primary_key = :location_id

  has_one :location_tag_map, foreign_key: :location_id

  default_scope do
    where(
      location_id: LocationTagMap
        .where(location_tag_id: LocationTag.where(name: 'Region').select(:location_tag_id))
        .select(:location_id)
    )
  end

  def as_json(options = {})
    super(options.merge(
      methods: %i[region_id]
    ))
  end

  def region_id
    self.location_id
  end
end
