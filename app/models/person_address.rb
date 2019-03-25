class PersonAddress < VoidableRecord
  self.table_name = 'person_address'
  self.primary_key = 'person_address_id'

  belongs_to :person, foreign_key: :person_id

  def current_district
    state_province
  end

  def current_district=(district)
    self.state_province = district
  end

  def current_village
    city_village
  end

  def current_village=(village)
    self.city_village = village
  end

  def current_traditional_authority
    township_division
  end

  def current_traditional_authority=(traditional_authority)
    self.township_division = traditional_authority
  end

  def home_district
    address2
  end

  def home_district=(district)
    self.address2 = district
  end

  def home_village
    neighborhood_cell
  end

  def home_village=(village)
    self.neighborhood_cell = village
  end

  def home_traditional_authority
    county_district
  end

  def home_traditional_authority=(traditional_authority)
    self.county_district = traditional_authority
  end

  def to_s
    [state_province, township_division, city_village].join ', '
  end

  # Looks for the most commonly used element in the database and sorts the results based on the first part of the string
  # def self.find_most_common(field_name, search_string)
  #   return self.find_by_sql(["SELECT DISTINCT #{field_name} AS #{field_name}, person_address_id AS id FROM person_address WHERE voided = 0 AND #{field_name} LIKE ? GROUP BY #{field_name} ORDER BY INSTR(#{field_name},\"#{search_string}\") ASC, COUNT(#{field_name}) DESC, #{field_name} ASC LIMIT 10", "%#{search_string}%"])
  # end
end
