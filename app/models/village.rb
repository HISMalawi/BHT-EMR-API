# frozen_string_literal: true

class Village < RetirableRecord
  self.table_name = :location
  self.primary_key = :location_id

  has_one :location_tag_map, foreign_key: :location_id
  belongs_to :traditional_authority, foreign_key: :parent_location

  default_scope do
    where(
      location_id: LocationTagMap
        .where(location_tag_id: LocationTag.where(name: 'Village').select(:location_tag_id))
        .select(:location_id)
    )
  end

  def as_json(options = {})
    super(options.merge(
      methods: %i[village_id]
    ))
  end

  def village_id
    self.location_id
  end
end
