# frozen_string_literal: true

module PersonService
  def self.create_person(gender, birth_date, birth_date_estimated)
    Person.create(
      gender: gender,
      birth_date: birth_date,
      birth_date_estimated: birth_date_estimated
    )
  end

  def self.create_person_name(person, given_name, family_name, middle_name = nil)
    PersonName.create(
      person: person,
      given_name: given_name,
      family_name: family_name,
      middle_name: middle_name
    )
  end

  def self.create_person_attributes(person, person_attributes)
    person_attributes.collect do |attr, value|
      attr_type = PersonAttributeType.where(name: attr).first
      unless attr_type
        Rails.logger.warn "Invalid person attribute type: #{attr}"
        next nil
      end
      PersonAttribute.create(
        person: person,
        person_attribute_type: attr_type,
        value: value
      )
    end
  end
end
