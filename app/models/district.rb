# frozen_string_literal: true

class District < RetirableRecord
  self.table_name = :location
  self.primary_key = :location_id

  has_one :location_tag_map, foreign_key: :location_id
  belongs_to :region, foreign_key: :parent_location, class_name: 'Region'

  def self.district_tag
    LocationTag.where(name: 'District').select(:location_tag_id)
  end

  def as_json(options = {})
    super(options.merge(
      methods: %i[district_id]
    ))
  end

  default_scope do
    where(
      location_id: LocationTagMap
        .where(location_tag_id: district_tag)
        .select(:location_id)
    )
  end

  def district_id
    self.location_id
  end
end
