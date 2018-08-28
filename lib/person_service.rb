# frozen_string_literal: true

require 'securerandom'

module PersonService
  def create_person(gender, birthdate, birthdate_estimated)
    Person.create(
      gender: gender,
      birthdate: birthdate,
      birthdate_estimated: birthdate_estimated,
      creator: User.current.id
    )
  end

  def create_person_name(person, given_name:, family_name:, middle_name: nil)
    PersonName.create(
      person: person,
      given_name: given_name,
      family_name: family_name,
      middle_name: middle_name,
      creator: User.current.id,
      # HACK: Manually set uuid because db requires it but has no default
      uuid: SecureRandom.uuid
    )
  end

  def create_person_attributes(person, person_attributes)
    person_attributes.collect do |attr, value|
      s_attr = attr.to_s.gsub(/_+/, ' ')
      attr_type = PersonAttributeType.where(name: s_attr).first
      unless attr_type
        Rails.logger.warn "Invalid person attribute type: #{attr}"
        next nil
      end
      PersonAttribute.create(
        person: person,
        type: attr_type,
        value: value,
        creator: User.current.id,
        # HACK: Manually set uuid because db requires it but has no default
        uuid: SecureRandom.uuid
      )
    end
  end
end
