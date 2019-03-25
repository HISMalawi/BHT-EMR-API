# frozen_string_literal: true

class PersonName < VoidableRecord
  self.table_name = 'person_name'
  self.primary_key = 'person_name_id'

  belongs_to :person, foreign_key: :person_id
  has_one :person_name_code, foreign_key: :person_name_id

  def self.validate_name_record(record, attr, value)
    return if value.empty?

    if !value.size.between?(2, 20)
      record.errors.add attr, 'Must be at least 2 and at most 20 characters long'
    elsif !(value.match?(/^\s*(!?\w+([-']\w+)*)+\s*$/) || value.match?('N/A'))
      record.errors.add attr, 'Does not look like a valid name'
    end
  end

  validates_each :given_name, :family_name do |record, attr, value|
    validate_name_record record, attr, value
  end

  validates_each :middle_name do |record, attr, value|
    # Validate value if set
    value && validate_name_record(record, attr, value)
  end

  # def before_save
  #   self.build_person_name_code(
  #     :person_name_id => self.person_name_id,
  #     :given_name_code => (self.given_name || '').soundex,
  #     :middle_name_code => (self.middle_name || '').soundex,
  #     :family_name_code => (self.family_name || '').soundex,
  #     :family_name2_code => (self.family_name2 || '').soundex,
  #     :family_name_suffix_code => (self.family_name_suffix || '').soundex)
  # end

  # Looks for the most commonly used element in the database and sorts the results based on the first part of the string
  # def self.find_most_common(field_name, search_string)
  #   return self.find_by_sql([
  #   "SELECT DISTINCT #{field_name} AS #{field_name}, #{self.primary_key} AS id \
  #    FROM person_name \
  #    INNER JOIN person ON person.person_id = person_name.person_id \
  #    WHERE person.voided = 0 AND person_name.voided = 0 AND #{field_name} LIKE ? \
  #    GROUP BY #{field_name} ORDER BY INSTR(#{field_name},\"#{search_string}\") ASC, COUNT(#{field_name}) DESC, #{field_name} ASC LIMIT 10", "%#{search_string}%"])
  # end
end
