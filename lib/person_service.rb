# frozen_string_literal: true

require 'securerandom'

module PersonService
  PERSON_TRUNK_FIELDS = %i[gender birthdate birthdate_estimated].freeze
  PERSON_NAME_FIELDS = %i[given_name family_name middle_name].freeze
  PERSON_ADDRESS_FIELDS = %i[current_district current_traditional_authority
                             current_village home_district
                             home_traditional_authority home_village].freeze
  PERSON_FIELDS = (PERSON_TRUNK_FIELDS + PERSON_NAME_FIELDS + PERSON_ADDRESS_FIELDS).freeze

  def self.create_person(params)
    Person.create(
      gender: params[:gender],
      birthdate: params[:birthdate],
      birthdate_estimated: params[:birthdate_estimated],
      creator: User.current.id
    )
  end

  def self.update_person(person, params)
    params = params.select { |k, _| PERSON_TRUNK_FIELDS.include? k }
    person.update params unless params.empty?
  end

  def self.create_person_name(person, params)
    PersonName.create(
      person: person,
      given_name: params[:given_name],
      family_name: params[:family_name],
      middle_name: params[:middle_name],
      creator: User.current.id,
      # HACK: Manually set uuid because db requires it but has no default
      uuid: SecureRandom.uuid
    )
  end

  def self.update_person_name(person, params)
    params = params.select { |k, _| PERSON_NAME_FIELDS.include? k }
    create_person_name person, params unless params.empty?
  end

  def self.create_person_address(person, params)
    PersonAddress.create(
      person: person,
      state_province: params[:current_district],
      city_village: params[:current_village],
      township_division: params[:current_traditional_authority],
      address2: params[:home_district],
      neighborhood_cell: params[:home_village],
      county_district: params[:home_traditional_authority],
      creator: User.current.id
    )
  end

  def self.update_person_address(person, params)
    params = params.select { |k, _| PERSON_ADDRESS_FIELDS.include? k }
    create_person_address(person, params) unless params.empty?
  end

  # def self.create_person_attributes(person, person_attributes)
  #   person_attributes.collect do |attr, value|
  #     s_attr = attr.to_s.gsub(/_+/, ' ')
  #     attr_type = PersonAttributeType.where(name: s_attr).first
  #     unless attr_type
  #       Rails.logger.warn "Invalid person attribute type: #{attr}"
  #       next nil
  #     end
  #     PersonAttribute.create(
  #       person: person,
  #       type: attr_type,
  #       value: value,
  #       creator: User.current.id,
  #       # HACK: Manually set uuid because db requires it but has no default
  #       uuid: SecureRandom.uuid
  #     )
  #   end
  # end
end
