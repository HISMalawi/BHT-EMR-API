# frozen_string_literal: true

require 'logger'
require 'securerandom'
require 'set'

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
    Person.transaction do
      person_params = params.select { |k, _| PERSON_TRUNK_FIELDS.include? k.to_sym }
      person.update!(person_params) unless person_params.empty?

      update_person_name(person, params)
      update_person_address(person, params)
      update_person_attributes(person, params)

      person
    end
  end

  def find_people_by_name_and_gender(given_name, middle_name, family_name, gender, use_soundex: true)
    if use_soundex
      soundex_person_search(given_name, middle_name, family_name, gender)
    else
      glob_person_search(given_name, middle_name, family_name, gender)
    end
  end

  def create_person_name(person, params)
    name = handle_model_errors do
      PersonName.create(person: person, given_name: params[:given_name],
                        family_name: params[:family_name], middle_name: params[:middle_name],
                        creator: User.current.id, uuid: SecureRandom.uuid)
    end

    NameSearchService.index_person_name(name)

    name
  end

  def update_person_name(person, params)
    params = params.select { |k, _| PERSON_NAME_FIELDS.include? k.to_sym }
    return nil if params.empty?

    name = person.names.first

    return create_person_name(person, params) unless name

    name = handle_model_errors do
      name.update(params)
      name
    end

    NameSearchService.index_person_name(name)

    name
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
    params = PERSON_ADDRESS_FIELDS.each_with_object({}) do |field, address_params|
      address_params[field] = params[field] if params[field]
    end

    return nil if params.empty?

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
    create_person_address(person, params)
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

  private

  # Search people by using the ART 1 & 2 soundex person search algorithm.
  def soundex_person_search(given_name, middle_name, family_name, gender)
    people = Person.all
    people = people.where('gender like ?', "#{gender}%") unless gender.blank?

    if given_name || family_name || middle_name
      # We may get names that match with an exact match but don't match with
      # soundex, vice-versa is also true, thus we capture both then combine them.
      filters = { given_name: given_name, middle_name: middle_name, family_name: family_name }
      raw_matches = NameSearchService.search_full_person_name(filters, use_soundex: false)
      soundex_matches = NameSearchService.search_full_person_name(filters, use_soundex: true)

      # Extract unique person_ids from the names matched above.
      person_ids = Set.new | raw_matches.collect(&:person_id) | soundex_matches.collect(&:person_id)

      people = people.where(person_id: person_ids)
    end

    people
  end

  # Search for people by matching using MySQL glob.
  def glob_person_search(given_name, middle_name, family_name, gender)
    people = Person.all
    people = people.where('gender like ?', "#{gender}%") unless gender.blank?

    if given_name || family_name
      filters = { given_name: gender, middle_name: middle_name, family_name: family_name }
      names = NameSearchService.search_full_person_name(filters, use_soundex: true)
      people = people.joins(:names).merge(names)
    end

    people
  end
end
