# app/models/location.rb
# frozen_string_literal: true

class Location < RetirableRecord
  self.table_name = :location
  self.primary_key = :location_id

  belongs_to :parent, class_name: 'Location', foreign_key: :parent_location, optional: true
  has_many :children, class_name: 'Location', foreign_key: :parent_location
  has_many :tag_maps, class_name: 'LocationTagMap', foreign_key: :location_id
  has_many :visits
  has_many :stages 
  has_many :location_attributes, foreign_key: 'location_id' 

  def self.current
    Thread.current['current_location']
  end

  def self.current=(location)
    Thread.current['current_location'] = location
  end

  def as_json(options = {})
      # Define the default inclusion for parent and district method
      default_includes = { parent: {} }
      default_methods = %i[district]
      
      # Start with the standard serialization
      attributes_data = super(options.merge(
        include: default_includes,
        methods: default_methods
      ))

      # Manually restructure the included location_attributes into the 'attributes' wrapper
      if options[:include] && options[:include][:location_attributes]
        # Extract the attribute options (like :only keys) from the controller's request
        attribute_options = options[:include][:location_attributes]
        
        # Remove the association from the standard options so it's not serialized twice
        options_without_attributes = options.deep_dup
        options_without_attributes[:include].delete(:location_attributes)
        
        # Re-call super with the modified options to get the base data structure
        attributes_data = super(options_without_attributes.merge(
          include: default_includes,
          methods: default_methods
        ))
        
        # Manually inject the attribute data under the correct nested key
        attributes_data[:attributes] = {
          location_attributes: location_attributes.as_json(
            only: attribute_options[:only] || %i[location_attribute_id attribute_type_id value_reference]
          )
        }
      end
      
      attributes_data
  end

  def self.current_health_center
    property = GlobalProperty.unscoped.find_by_property('current_health_center_id')
    raise 'Global property current_health_center not set' unless property

    Location.find(property.property_value)
  end

  def district
    city_village
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

    label = ZebraPrinter::Lib::StandardLabel.new
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

  # Geospatial methods for facility-like functionality
  def coordinates
    return nil if latitude.blank? || longitude.blank?
    [latitude.to_f, longitude.to_f]
  end

  def has_coordinates?
    coordinates.present?
  end

  def distance_to(other_location)
    return nil unless has_coordinates? && other_location.has_coordinates?

    rad_per_deg = Math::PI / 180
    earth_radius = 6371 # km

    lat1 = latitude.to_f * rad_per_deg
    lat2 = other_location.latitude.to_f * rad_per_deg
    lon1 = longitude.to_f * rad_per_deg
    lon2 = other_location.longitude.to_f * rad_per_deg

    dlon = lon2 - lon1
    dlat = lat2 - lat1

    a = Math.sin(dlat / 2)**2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dlon / 2)**2
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))

    (earth_radius * c).round(3)
  end

  def nearby_facilities(radius_km = 10)
    return [] unless has_coordinates?

    # Rough approximation: 1 degree = 111km
    lat_degree_range = radius_km / 111.0
    lng_degree_range = radius_km / (111.0 * Math.cos(latitude.to_f * Math::PI / 180))

    Location.where.not(location_id: location_id)
            .where(latitude: (latitude.to_f - lat_degree_range)..(latitude.to_f + lat_degree_range))
            .where(longitude: (longitude.to_f - lng_degree_range)..(longitude.to_f + lng_degree_range))
            .select { |loc| distance_to(loc) <= radius_km }
  end

  def self.search_by_coordinates(lat, lng, radius_km = 10)
    return none unless lat.present? && lng.present?

    lat = lat.to_f
    lng = lng.to_f

    # Create temporary location for distance calculation
    temp_location = new(latitude: lat, longitude: lng)

    # Find locations within rough square first
    lat_degree_range = radius_km / 111.0
    lng_degree_range = radius_km / (111.0 * Math.cos(lat * Math::PI / 180))

    where.not(latitude: nil)
      .where.not(longitude: nil)
      .where(latitude: (lat - lat_degree_range)..(lat + lat_degree_range))
      .where(longitude: (lng - lng_degree_range)..(lng + lng_degree_range))
      .select { |loc| temp_location.distance_to(loc) <= radius_km }
  end
end
