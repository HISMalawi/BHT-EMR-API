# frozen_string_literal: true

require 'securerandom'
require 'dde_client'
require 'person_service'
require 'zebra_printer/init'

class Api::V1::PatientsController < ApplicationController
  # TODO: Refactor the business logic here into a service class

  before_action :load_dde_client

  def show
    render json: Patient.find(params[:id])
  end

  def search_by_npid
    npid = params.require(:npid)
    patients = Patient.joins(:patient_identifiers).where(
      'patient_identifier.identifier_type = ? AND patient_identifier.identifier = ?',
      npid_identifier_type.patient_identifier_type_id, npid
    )

    return render(json: paginate(patients)) unless patients.empty? && dde_enabled?

    # Ignore response status, DDE almost always returns 200 even for bad requests
    # and 404s on this endpoint. Only way to check for an error is to check whether we
    # received a hash and the hash contains an error... Not pretty.
    response, = @dde_client.post 'search_by_npid', npid: npid

    unless response.class == Array
      logger.error "Failed to search for patient in DDE by npid: #{response}"
      return render json: { errors: 'DDE is unreachable...' },
                    status: :internal_server_error
    end

    render json: response.collect { |dde_person| dde_person_to_openmrs dde_person }
  end

  def create
    create_params, errors = required_params required: %i[person_id]
    return render json: { errors: create_params }, status: :bad_request if errors

    person = Person.find(create_params[:person_id])
    patient_identifier = dde_enabled? ? register_dde_patient(person) : gen_v3_npid(person)

    patient = Patient.create patient_id: person.id,
                             creator: User.current.id,
                             date_created: Time.now

    patient.patient_identifiers << patient_identifier

    unless patient.save
      logger.error "Failed to create patient: #{patient.errors.as_json}"
      render json: { errors: ['Failed to create person'] }, status: :internal_server_error
      return
    end

    render json: patient, status: :created
  end

  def update
    patient = Patient.find(params[:id])

    new_person_id = params.permit(:person_id)[:person_id]
    if new_person_id
      patient.person_id = new_person_id
      return render json: patient.errors, status: :bad_request unless patient.save
    end

    render json: patient unless dde_enabled?

    dde_person = openmrs_to_dde_person(patient.person)
    dde_response, dde_status = @dde_client.post 'update_person', dde_person

    unless dde_status == 200
      logger.error "Failed to update person in DDE: #{dde_response}"
      render json: { errors: 'Failed to update person in DDE'},
             status: :internal_server_error
      return
    end

    render json: patient, status: :ok
  end

  def print_national_health_id_label
    patient = Patient.find(params[:patient_id])

    label = generate_national_id_label patient
    send_data label, type: 'application/label;charset=utf-8',
                     stream: false,
                     filename: "#{params[:patient_id]}-#{SecureRandom.hex(12)}.lbl",
                     disposition: 'inline'
  end

  def visits
    patient_id = params[:patient_id]

    sql_stmnt = ActiveRecord::Base.connection.raw_connection.prepare VISIT_DATES_SQL
    visits = sql_stmnt.execute(patient_id).collect { |visit| visit[0] }

    render json: visits
  end

  private

  DDE_CONFIG_PATH = 'config/application.yml'

  VISIT_DATES_SQL = <<END_QUERY
    SELECT DISTINCT DATE(encounter_datetime) AS encounter_datetime
    FROM encounter WHERE patient_id = ?
    GROUP BY encounter_datetime
    ORDER BY encounter_datetime DESC
END_QUERY

  def load_dde_client
    return unless dde_enabled?

    @dde_client = DDEClient.new

    logger.debug 'Searching for a stored DDE connection'
    connection = Rails.application.config.dde_connection
    unless connection
      logger.debug 'No stored DDE connection found... Loading config...'
      app_config = YAML.load_file DDE_CONFIG_PATH
      Rails.application.config.dde_connection = @dde_client.connect(
        config: {
          username: app_config['dde_username'],
          password: app_config['dde_password'],
          base_url: app_config['dde_url']
        }
      )
      return
    end

    logger.debug 'Stored DDE connection found'
    @dde_client.connect connection: connection
  end

  def dde_enabled?
    property = GlobalProperty.find_by(property: 'dde_enabled')
    return false unless property
    value = (property.property_value || '0').strip
    enabled = property && !['0', 'false', 'f', ''].include?(value)
    logger.debug "DDE Enabled: #{enabled}"
    logger.info 'DDE is not enabled' unless enabled
    enabled
  end

  # Converts an openmrs person structure to a DDE person structure
  def openmrs_to_dde_person(person)
    logger.debug "Converting OpenMRS person to dde_person: #{person}"
    person_name = person.names[0]
    person_address = person.addresses[0]
    person_attributes = filter_person_attributes person.person_attributes

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

    logger.debug "Converted openmrs person to dde_person: #{dde_person}"
    dde_person
  end

  # Convert a DDE person to an openmrs person.
  #
  # NOTE: This creates a person on the database.
  def dde_person_to_openmrs(dde_person)
    logger.debug "Converting DDE person to openmrs: #{dde_person}"

    person = PersonService.create_person(
      birthdate: dde_person['birthdate'],
      birthdate_estimated: dde_person['birthdate_estimated'],
      gender: dde_person['gender']
    )

    PersonService.create_person_name(
      person, given_name: dde_person['given_name'],
              family_name: dde_person['family_name'],
              middle_name: dde_person['middle_name']
    )

    PersonService.create_person_address(
      person, home_village: dde_person['home_village'],
              home_traditional_authority: dde_person['home_traditional_authority'],
              home_district: dde_person['home_district'],
              current_village: dde_person['current_village'],
              current_traditional_authority: dde_person['current_traditional_authority'],
              current_district: dde_person['current_district']
    )

    PersonService.create_person_attributes(
      person, cell_phone_number: dde_person['cellphone_number'],
              occupation: dde_person['occupation']
    )

    person
  end

  def register_dde_patient(person)
    dde_person = openmrs_to_dde_person(person)
    dde_response, dde_status = @dde_client.post 'add_person', dde_person

    if dde_status != 200
      logger.error "Failed to create person in DDE: #{dde_response}"
      raise 'Failed to register person in DDE'
    end

    PatientIdentifier.new(
      identifier: dde_response['npid'],
      identifier_type: npid_identifier_type.id,
      creator: User.current.id,
      date_created: Time.now,
      uuid: SecureRandom.uuid,
      location_id: Location.current.id
    )
  end

  def gen_v3_npid(person)
    identifier_type = PatientIdentifierType.find_by name: 'National id'
    identifier_type.next_identifier person
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

  def find_patient(npid)
    @dde_service.find_patient(npid)
  end

  def generate_national_id_label(patient)
    person = patient.person

    national_id = patient.national_id
    return nil unless national_id

    sex =  "(#{person.gender})"
    address = person.addresses.first.to_s.strip[0..24].humanize
    label = ZebraPrinter::StandardLabel.new
    label.font_size = 2
    label.font_horizontal_multiplier = 2
    label.font_vertical_multiplier = 2
    label.left_margin = 50
    label.draw_barcode(50, 180, 0, 1, 5, 15, 120, false, national_id)
    label.draw_multi_text(person.name.titleize)
    label.draw_multi_text("#{patient.national_id_with_dashes} #{person.birthdate}#{sex}")
    label.draw_multi_text(address)
    label.print(1)
  end

  def npid_identifier_type
    PatientIdentifierType.find_by_name('National id')
  end
end
