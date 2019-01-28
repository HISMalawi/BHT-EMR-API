# frozen_string_literal: true

require 'logger'

class DDEService
  DDE_CONFIG_PATH = 'config/application.yml'
  LOGGER = Logger.new(STDOUT)

  cattr_accessor :connection # Holds current (shared) connection to DDE

  include ModelUtils

  def find_patients_by_npid(npid)
    # Ignore response status, DDE almost always returns 200 even for bad
    # requests and 404s on this endpoint. Only way to check for an error
    # is to check whether we received a hash and the hash contains an
    # error... Not pretty.
    response, _status = dde_client.post('search_by_npid', npid: npid)

    unless response.class == Array
      raise "Patient search failed: DDE is unreachable: DDE Response => #{response}"
    end

    response.collect { |dde_person| dde_person_to_openmrs(dde_person) }
  end

  # Registers local OpenMRS patient in DDE
  #
  # On success patient get two identifiers under the types
  # 'DDE person document ID' and 'National id'. The
  # 'DDE person document ID' is the patient's record ID in the local
  # DDE instance and the 'National ID' is the national unique identifier
  # for the patient.
  def create_patient(patient)
    dde_person = openmrs_to_dde_person(patient.person)
    dde_response, dde_status = dde_client.post('add_person', dde_person)

    unless dde_status == 200
      raise "Failed to register person in DDE: DDE Response => #{dde_response}"
    end

    create_local_patient_identifier(patient, dde_response['doc_id'], 'DDE person document ID')
    create_local_patient_identifier(patient, dde_response['npid'], 'National id')
  end

  # Updates patient demographics in DDE.
  #
  # Local patient is not affected in anyway by the update
  def update_patient(patient)
    dde_person = openmrs_to_dde_person(patient.person)
    response, status = dde_client.post('update_person', dde_person)

    raise "Failed to update person in DDE: #{response}" unless status == 200

    patient
  end

  def re_assign_npid(dde_patient_id)
    dde_client.post('assign_npid', doc_id: dde_patient_id)
  end

  private

  def dde_client
    return @dde_client if @dde_client

    @dde_client = DDEClient.new

    LOGGER.debug 'Searching for a stored DDE connection'
    if DDEService.connection
      LOGGER.debug 'Stored DDE connection found'
      @dde_client.connect(connection: DDEService.connection)
      return @dde_client
    end

    LOGGER.debug 'No stored DDE connection found... Loading config...'
    DDEService.connection = @dde_client.connect(config: config)
    @dde_client
  end

  def config
    app_config = YAML.load_file(DDE_CONFIG_PATH)
    {
      username: app_config['dde_username'],
      password: app_config['dde_password'],
      base_url: app_config['dde_url']
    }
  end

  # Converts an openmrs person structure to a DDE person structure
  def openmrs_to_dde_person(person)
    LOGGER.debug "Converting OpenMRS person to dde_person: #{person}"
    person_name = person.names[0]
    person_address = person.addresses[0]
    person_attributes = filter_person_attributes(person.person_attributes)

    dde_person = {
      given_name: person_name.given_name,
      family_name: person_name.family_name,
      gender: person.gender,
      birthdate: person.birthdate,
      birthdate_estimated: person.birthdate_estimated, # Convert to bool?
      attributes: {
        current_district: person_address ? person_address.state_province : nil,
        current_traditional_authority: person_address ? person_address.township_division : nil,
        current_village: person_address ? person_address.city_village : nil,
        home_district: person_address ? person_address.address2 : nil,
        home_village: person_address ? person_address.neighborhood_cell : nil,
        home_traditional_authority: person_address ? person_address.county_district : nil,
        occupation: person_attributes ? person_attributes[:occupation] : nil
      }
    }

    LOGGER.debug "Converted openmrs person to dde_person: #{dde_person}"
    dde_person
  end

  # Convert a DDE person to an openmrs person.
  #
  # NOTE: This creates a person on the database.
  def dde_person_to_openmrs(dde_person)
    LOGGER.debug "Converting DDE person to openmrs: #{dde_person}"

    person = person_service.create_person(
      birthdate: dde_person['birthdate'],
      birthdate_estimated: dde_person['birthdate_estimated'],
      gender: dde_person['gender']
    )

    person_service.create_person_name(
      person, given_name: dde_person['given_name'],
              family_name: dde_person['family_name'],
              middle_name: dde_person['middle_name']
    )

    person_service.create_person_address(
      person, home_village: dde_person['home_village'],
              home_traditional_authority: dde_person['home_traditional_authority'],
              home_district: dde_person['home_district'],
              current_village: dde_person['current_village'],
              current_traditional_authority: dde_person['current_traditional_authority'],
              current_district: dde_person['current_district']
    )

    person_service.create_person_attributes(
      person, cell_phone_number: dde_person['cellphone_number'],
              occupation: dde_person['occupation']
    )

    person
  end

  def create_local_patient_identifier(patient, value, type_name)
    identifier = PatientIdentifier.create(identifier: value,
                                          type: patient_identifier_type(type_name),
                                          location_id: Location.current.id,
                                          patient: patient)
    return identifier if identifier.errors.empty?

    raise "Could not save DDE identifier: #{type_name} due to #{identifier.errors.as_json}"
  end

  def filter_person_attributes(person_attributes)
    return nil unless person_attributes

    person_attributes.each_with_object({}) do |attr, filtered|
      case attr.type.name.downcase.gsub(/\s+/, '_')
      when 'cell_phone_number'
        filtered[:cell_phone_number] = attr.value
      when 'occupation'
        filtered[:occupation] = attr.value
      when 'birthplace'
        filtered[:home_district] = attr.value
      when 'home_village'
        filtered[:home_village] = attr.value
      when 'ancestral_traditional_authority'
        filtered[:home_traditional_authority] = attr.value
      end
    end
  end
end
