require "uri"
require "json"
require "net/http"

class Api::V1::SendSmsController < ApplicationController
  before_action :initialize_variables, only: [:index, :fetch_phone]

  def index
    return render json: { message: "SMS reminder turned off" } if sms_reminder_off?
    output = process_sms_request
    render json: { message: output }
  end

  def fetch_phone
    phone_number = validated_phone_number
    render json: { message: phone_number }
  end

  def show
    config_file = Rails.root.join('config', 'application.yml')
    config = YAML.load_file(config_file) 
    enviroment = active_enviroment

    if config.key?(enviroment)
      render json: config[enviroment]
    else
      render json: { error: "#{enviroment} configuration not found" }, status: :not_found
    end
  rescue Errno::ENOENT
    render json: { error: 'Configuration file not found' }, status: :not_found
  end

  def update
    config_file = Rails.root.join('config', 'application.yml')
    temp_file = Rails.root.join('config', 'application_temp.yml')
  
    File.open(temp_file, 'w') do |file|
      File.foreach(config_file) do |line|
        key_value_match = line.match(/^\s*(\w+):\s*(.*)$/)
  
        if key_value_match && params.key?(key_value_match[1])
          key = key_value_match[1]
          value = params[key]
          indent = line[/^\s*/]  # Preserve the indentation
          line = "#{indent}#{key}: #{value}\n"
        end
  
        file.write(line)
      end
    end
  
    File.rename(temp_file, config_file)
  
    config = YAML.load_file(config_file)
    enviroment = active_enviroment
    render json: config[enviroment], status: :ok
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end
  

  private

  def initialize_variables
    @patient = Observation.where(voided: 0, person_id: params[:person_id])
                          .group(:person_id)
                          .joins("INNER JOIN encounter ON encounter.encounter_id = obs.encounter_id AND encounter.encounter_type = #{EncounterType.find_by_name('APPOINTMENT').id}")
                          .joins("INNER JOIN person ON person.person_id = obs.person_id")
                          .joins("INNER JOIN person_name ON person_name.person_id = obs.person_id")
                          .joins("INNER JOIN person_attribute ON person_attribute.person_id = obs.person_id AND person_attribute.person_attribute_type_id = #{PersonAttributeType.find_by_name('Cell Phone Number').person_attribute_type_id}")
                          .where(encounter: { program_id: 33, voided: 0 })
                          .select("obs.person_id AS person_id, person.birthdate AS birthdate, person.gender AS gender,
                                   person_name.given_name AS firstname, person_name.family_name AS sirname, person_attribute.value AS phone")
                          .map do |patient|
                            {
                              person_id: patient.person_id,
                              firstname: patient.firstname,
                              sirname: patient.sirname,
                              dob: patient.birthdate,
                              gender: patient.gender,
                              person_phone: patient.phone
                            }
                          end
  end

  def active_enviroment

    environment = Rails.env
    case environment

    when "development"
      return 'development'
    when "production"
      return 'production'
    when "test"
      return 'test'
    end

  end

  def patients_phone
    patient_details = { demographics: {}, cell_phone: 0 }

    @patient.each do |patient|
      patient_details[:demographics] = patient
      age_in_days = (Date.today - patient[:dob]).to_i

      patient_details[:cell_phone] = age_in_days < 5840 ? guardian_phone : patient[:person_phone]
    end

    patient_details
  end

  def guardian_phone
    filters = params.permit %i[person_b relationship]
    relationships = service.find_relationships(filters)
    relationships[0].relation.try(:person_attributes)
                    .try(:find_by, person_attribute_type_id: PersonAttributeType.find_by_name('Cell Phone Number').id)
                    .try(:value)
  end

  def service
    PersonRelationshipService.new(Person.find(params[:person_id]))
  end

  def enqueue_sms(date, details)
    ImmunizationService::SendSmsService.perform_async(date, details)
  rescue => e
    "Failed to queue SMS: #{e.message}"
  end

  def validatephone(phone)
    phone = "+265" + phone[1..] if phone.present? && phone.starts_with?('0')
    phone_pattern = /\A\+\d{12}\z/
    phone_pattern.match?(phone) ? phone : "Invalid phone number"
  end

  def validated_phone_number
    patient_details = patients_phone
    validatephone(patient_details[:cell_phone])
  end

  def sms_reminder_off?
    config_file = Rails.root.join('config', 'application.yml')
    config = YAML.load_file(config_file)
    enviroment = active_enviroment
    config.dig(enviroment, 'sms_reminder') == 'false'
  end

  def process_sms_request
    phone_number = validated_phone_number
    if phone_number.length == 13
      patient_details = patients_phone
      patient_details[:cell_phone] = phone_number
      enqueue_sms(params[:appointment_date], patient_details)
    else
      phone_number
    end
  end
end
