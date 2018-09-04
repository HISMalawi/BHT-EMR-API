# frozen_string_literal: true

class Location < RetirableRecord
  self.table_name = :location
  self.primary_key = :location_id

  cattr_accessor :current_location

  def site_id
    Location.current_health_center.location_id.to_s
  end

  # # Looks for the most commonly used element in the database and sorts the results based on the first part of the string
  # def self.most_common_program_locations(search)
  #   (find_by_sql([
  #                  "SELECT DISTINCT location.name AS name, location.location_id AS location_id \
  #                   FROM location \
  #                   INNER JOIN patient_program ON patient_program.location_id = location.location_id AND patient_program.voided = 0 \
  #                   WHERE location.retired = 0 AND name LIKE ? \
  #                   GROUP BY patient_program.location_id \
  #                   ORDER BY INSTR(name, ?) ASC, COUNT(name) DESC, name ASC \
  #                   LIMIT 10",
  #                  "%#{search}%", search.to_s
  #                ]) + [current_health_center]).uniq
  # end

  # def self.most_common_locations(search)
  #   find_by_sql([
  #                 "SELECT DISTINCT location.name AS name, location.location_id AS location_id \
  #                  FROM location \
  #                  WHERE location.retired = 0 AND name LIKE ? \
  #                  ORDER BY name ASC \
  #                  LIMIT 10",
  #                 "%#{search}%"
  #               ]).uniq
  # end

  def children
    return [] if name =~ / - /
    Location.find(:all, conditions: ['name LIKE ?', '%' + name + ' - %'])
  end

  def parent
    return nil unless name =~ /(.*) - /
    Location.find_by_name(Regexp.last_match(1))
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

  def self.current_health_center
    property = GlobalProperty.find_by_property('current_health_center_id')
    @@current_health_center ||= Location.find(property.property_value)
  rescue StandardError => e
    logger.warn "Suppressed error: #{e}"
    current_location
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
