# frozen_string_literal: true

class Location < RetirableRecord
  self.table_name = :location
  self.primary_key = :location_id

  belongs_to :parent, class_name: 'Location', foreign_key: :parent_location, optional: true
  has_many :children, class_name: 'Location', foreign_key: :parent_location
  has_many :tag_maps, class_name: 'LocationTagMap', foreign_key: :location_id

  def self.current
    Thread.current['current_location']
  end

  def self.current=(location)
    Thread.current['current_location'] = location
  end

  def as_json(options = {})
    super(options.merge(include: { parent: {} }))
  end

  def self.current_health_center
    property = GlobalProperty.find_by_property('current_health_center_id')
    health_center = Location.find_by(location_id: property.property_value)

    unless health_center
      logger.warn "Property current_health_center not set: #{e}"
      return nil
    end

    health_center
  end

  def site_id
    Location.current_health_center.location_id.to_s
  end

  def related_locations_including_self
    if parent
      parent.children + [self]
    else
      children + [self]
    end
  end

  def related_to_location?(location)
    site_name == location.site_name
  end

  def self.current_arv_code
    current_health_center.neighborhood_cell
  rescue StandardError
    nil
  end

  def location_label
    return unless location_id
    label = ZebraPrinter::StandardLabel.new
    label.font_size = 2
    label.font_horizontal_multiplier = 2
    label.font_vertical_multiplier = 2
    label.left_margin = 50
    label.draw_barcode(50, 180, 0, 1, 5, 15, 120, false, location_id.to_s)
    label.draw_multi_text(name.to_s)
    label.print(1)
  end

  def self.workstation_locations
    field_name = 'name'

    sql = "SELECT *
           FROM location
           WHERE location_id IN (SELECT location_id
                        FROM location_tag_map
                        WHERE location_tag_id = (SELECT location_tag_id
                               FROM location_tag
                               WHERE name = 'Workstation Location'))
           ORDER BY name ASC"

    begin
      Location.find_by_sql(sql).collect { |name| name.send(field_name) }
    rescue StandardError
      []
    end
  end

  def self.search(search_string, act)
    field_name = 'name'
    if %w[delete print].include? act
      sql = "SELECT *
             FROM location
             WHERE location_id IN (SELECT location_id
                          FROM location_tag_map
                          WHERE location_tag_id = (SELECT location_tag_id
	                                   FROM location_tag
	                                   WHERE name = 'Workstation Location'))
             ORDER BY name ASC"
    elsif act == 'create'
      sql = "SELECT *
             FROM location
             WHERE location_id NOT IN (SELECT location_id
                          FROM location_tag_map
                          WHERE location_tag_id = (SELECT location_tag_id
	                                   FROM location_tag
                                     WHERE name = 'Workstation Location'))
                          AND name LIKE '%#{search_string}%'
             ORDER BY name ASC"
    end
    find_by_sql(sql).collect { |name| name.send(field_name) }
  end
end
