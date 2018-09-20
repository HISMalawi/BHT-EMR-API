# frozen_string_literal: true

require 'logger'
require 'securerandom'

module PersonService
  LOGGER = Logger.new STDOUT

  PERSON_TRUNK_FIELDS = %i[gender birthdate birthdate_estimated].freeze
  PERSON_NAME_FIELDS = %i[given_name family_name middle_name].freeze
  PERSON_ADDRESS_FIELDS = %i[current_district current_traditional_authority
                             current_village home_district
                             home_traditional_authority home_village].freeze
  PERSON_FIELDS = (PERSON_TRUNK_FIELDS + PERSON_NAME_FIELDS + PERSON_ADDRESS_FIELDS).freeze

  # Map of API person attributes to database names
  PERSON_ATTRIBUTES_FIELDS = {
    cell_phone_number: 'Cell Phone Number',
    landmark: 'Landmark Or Plot Number',
    next_of_kin: 'NEXT OF KIN',
    next_of_kin_contact_number: 'NEXT OF KIN CONTACT NUMBER',
    occupation: 'Occupation'
  }.freeze

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

  def self.create_person_attributes(person, person_attributes)
    person_attributes.each do |field, value|
      field = field.to_sym

      next unless PERSON_ATTRIBUTES_FIELDS.include? field

      LOGGER.debug "Creating attr #{field} = #{value}"

      type = PersonAttributeType.find_by name: PERSON_ATTRIBUTES_FIELDS[field]
      attr = PersonAttribute.create(
        person_id: person.id,
        person_attribute_type_id: type.person_attribute_type_id,
        value: value
      )

      unless attr.errors.empty?
        raise "Failed to save attr: #{field} = #{value} due to #{attr.errors}"
      end
    end
  end

  def self.update_person_attributes(person, person_attributes)
    LOGGER.debug person_attributes

    person_attributes.each do |field, value|
      field = field.to_sym

      next unless PERSON_ATTRIBUTES_FIELDS.include? field

      LOGGER.debug "Updating attr #{field} = #{value}"

      type = PersonAttribute.find_by name: PERSON_ATTRIBUTES_FIELDS[field]
      attr = PersonAttribute.find_by person_attribute_type_id: type.id,
                                     person_id: person.id
      saved = attr.update(field => value)

      unless saved
        raise "Failed to save attr: #{field} = #{value} due to #{attr.errors}"
      end
    end
  end
end
