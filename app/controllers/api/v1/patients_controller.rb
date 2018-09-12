# frozen_string_literal: true

require 'securerandom'
require 'dde_client'
require 'zebra_printer/init'

class Api::V1::PatientsController < ApplicationController
  before_action :load_dde_client

  def show
    response, status = @dde_client.post 'search_by_npid', { npid: params[:id] }
    if status == 200
      render json: response
    else
      logger.error "DDE Error: Status - #{status} - #{response}"
      render json: { errors: ['Unable to communicate with DDE'] }, status: :internal_server_error
    end
  end

  def get
    patient = find_patient params[:id]
    unless patient
      errors = ["Patient ##{params[:id]} not found"]
      render json: { errors: errors }, status: :bad_request
      return
    end
    render json: patient
  end

  def create
    create_params, errors = required_params required: %i[person_id]
    return render json: { errors: create_params }, status: :bad_request if errors

    person = Person.find(create_params[:person_id])
    response, status = @dde_client.post 'add_person', openmrs_to_dde_person(person)

    if status != 200
      errors = ['Failed to create person in DDE']
      render json: { errors: errors, dde_response: response }, status: :internal_server_error
      return
    end

    patient = Patient.create patient_id: person.id,
                             creator: User.current.id,
                             date_created: Time.now

    patient_identifier = PatientIdentifier.create(
      identifier: response['npid'],
      identifier_type: PatientIdentifierType.find_by_name('National id').id,
      creator: User.current.id,
      patient: patient,
      date_created: Time.now,
      uuid: SecureRandom.uuid,
      location_id: Location.current.id
    )

    patient.patient_identifiers << patient_identifier

    unless patient.save
      logger.error "Failed to create patient: #{patient.errors.as_json}"
      render json: { errors: ['Failed to create person'] }, status: :internal_server_error
      return
    end

    render json: patient, status: :created
  end

  def print_national_health_id_label
    patient = Patient.find(params[:patient_id])

    label = generate_national_id_label patient
    send_data label, type: 'application/label;charset=utf-8',
                     stream: false,
                     filename: "#{params[:patient_id]}-#{SecureRandom.hex(12)}.lbl",
                     disposition: 'inline'
  end

  private

  DDE_CONFIG_PATH = 'config/application.yml'

  def load_dde_client
    @dde_client = DDEClient.new

    logger.debug 'Searching for a stored DDE connection'
    connection = Rails.application.config.dde_connection
    if connection
      logger.debug 'Stored DDE connection found'
      @dde_client.connect connection: connection
    else
      logger.debug 'No stored DDE connection found... Loading config...'
      app_config = YAML.load_file DDE_CONFIG_PATH
      Rails.application.config.dde_connection = @dde_client.connect(
        config: {
          username: app_config['dde_username'],
          password: app_config['dde_password'],
          base_url: app_config['dde_url']
        }
      )
    end
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
end
