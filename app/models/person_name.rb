# frozen_string_literal: true

class PersonName < VoidableRecord
  self.table_name = 'person_name'
  self.primary_key = 'person_name_id'

  belongs_to :person, foreign_key: :person_id
  has_one :person_name_code, foreign_key: :person_name_id

  def self.validate_name_record(record, attr, value)
    return if value&.blank?

    if value.nil?
      record.errors.add(attr, 'Name cannot be nil')
    elsif !value.size.between?(2, 20)
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

  def to_s
    formatted_middle_name = name?(middle_name) ? " #{middle_name} " : ' '

    "#{given_name}#{formatted_middle_name}#{family_name}"
  end

  private

  # Checks if name is set
  def name?(name)
    name = name&.strip
    !(name.blank? || name.match?(%r{(N[/\\]+A|UNKNOWN)}i))
  end
end
