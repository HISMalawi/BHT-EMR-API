# frozen_string_literal: true

require 'logger'
require 'securerandom'

class PersonService
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

  def create_person(params)
    handle_model_errors do
      Person.create(
        gender: params[:gender],
        birthdate: params[:birthdate],
        birthdate_estimated: params[:birthdate_estimated],
        creator: User.current.id
      )
    end
  end

  def update_person(person, params)
    params = params.select { |k, _| PERSON_TRUNK_FIELDS.include? k.to_sym }
    person.update params unless params.empty?
  end

  def find_people_by_name_and_gender(given_name, family_name, gender)
    Person.joins([:patient, :names]).where(
      'person.gender like ? AND person_name.given_name LIKE ?
                            AND person_name.family_name LIKE ?
       AND patient.patient_id = person.person_id',
      "#{gender}%", "#{given_name}%", "#{family_name}%"
    )
  end

  def create_person_name(person, params)
    handle_model_errors do
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
  end

  def update_person_name(person, params)
    params = params.select { |k, _| PERSON_NAME_FIELDS.include? k.to_sym }
    return nil if params.empty?

    name = person.names.first

    return create_person_name(person, params) unless name

    handle_model_errors do
      name.update(params)
      name
    end
  end

  PERSON_ADDRESS_FIELD_MAP = {
    current_district: :state_province,
    current_village: :city_village,
    current_traditional_authority: :township_division,
    home_district: :address2,
    home_village: :neighborhood_cell,
    home_traditional_authority: :county_district,
  }

  def create_person_address(person, params)
    handle_model_errors do
      person.addresses.each do |address|
        address.void('Address updated')
      end

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
  end

  def update_person_address(person, params)
    return create_person_address(person, params)
  end

  def create_person_attributes(person, person_attributes)
    person_attributes.each do |field, value|
      field = field.to_sym

      next unless PERSON_ATTRIBUTES_FIELDS.include?(field.to_sym) && value

      LOGGER.debug "Creating attr #{field} = #{value}"

      type = PersonAttributeType.find_by name: PERSON_ATTRIBUTES_FIELDS[field]
      handle_model_errors do
        PersonAttribute.create(
          person_id: person.id,
          person_attribute_type_id: type.person_attribute_type_id,
          value: value
        )
      end
    end
  end

  def update_person_attributes(person, person_attributes)
    LOGGER.debug person_attributes

    person_attributes.each do |field, value|
      field = field.to_sym

      next unless PERSON_ATTRIBUTES_FIELDS.include? field.to_sym

      LOGGER.debug "Updating attr #{field} = #{value}"

      type = PersonAttributeType.find_by name: PERSON_ATTRIBUTES_FIELDS[field]
      attr = PersonAttribute.find_by person_attribute_type_id: type.id,
                                     person_id: person.id

      return PersonAttribute.create(type: type, person: person, value: value) unless attr

      handle_model_errors do
        attr.update(value: value)
        attr
      end
    end
  end

  def handle_model_errors
    model_instance = yield
    return model_instance if model_instance.errors.empty?

    error = InvalidParameterError.new('Invalid parameter(s)')
    error.model_errors = model_instance.errors
    raise error
  end
end
