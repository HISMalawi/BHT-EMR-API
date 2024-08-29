require "uri"
require "json"
require "net/http"

class Api::V1::SendSmsController < ApplicationController
  before_action :initialize_variables, only: [:index, :cancel]

  def index
      patient_details = patients_phone
      output = enqueue_sms(params[:appointment_date], patient_details,'send_appointment')
      render json: { message: patient_details }
  end

  def cancel
    patient_details = patients_phone
    output = enqueue_sms(params[:appointment_date], patient_details,'cancel_appointment')
    render json: { message: patient_details }
  end

  def show

    globalconfig = fetch_configuration_from_global_property(User.current.location_id)
    config = fetch_default_configuration

    if !globalconfig.empty?

      globalconfig.each do |key,value|
            config[key] = value
      end
      
    end

    render json: config
  rescue Errno::ENOENT
    render json: { error: 'Configuration file not found' }, status: :not_found
  end

  def update
    begin
      params.each do |key, value|
        if ["next_appointment_message", "cancel_appointment_message"].include?(key)
          GlobalProperty.find_or_initialize_by(property: "#{User.current.location_id}_#{key}").update(property_value: value)
        end
      end
  
      config_file = Rails.root.join('config', 'application.yml')
        temp_file = Rails.root.join('config', 'application_temp.yml')
  
      File.open(temp_file, 'w') do |file|
        File.foreach(config_file) do |line|
          if (key_value_match = line.match(/^\s*(\w+):\s*(.*)$/)) && params.key?(key_value_match[1])
            key = key_value_match[1]
            value = params[key]
            indent = line[/^\s*/]
            line = "#{indent}#{key}: #{value}\n"
          end
          file.write(line)
        end
      end
  
      File.rename(temp_file, config_file)
      config = YAML.load_file(config_file)
      environment = Rails.env
  
      render json: { message: config["eir_sms_configurations"][environment] }, status: :ok
    rescue StandardError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
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
                              person_phone: patient.phone.gsub(/\s+/, '')
                            }
                          end
  end

  def fetch_configuration_from_global_property(facility_id)
    GlobalProperty.where("property", "#{facility_id}_%")
                  .map { |gp| [gp.property.sub("#{facility_id}_", ''), gp.property_value] }
                  .to_h
  end

  def fetch_default_configuration
    config_file = Rails.root.join('config', 'application.yml')
    YAML.load_file(config_file)["eir_sms_configurations"][Rails.env] || {}
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
                    .try(:value).gsub(/\s+/, '')
  end

  def service
    PersonRelationshipService.new(Person.find(params[:person_id]))
  end

  def enqueue_sms(date, details, action)
    ImmunizationService::SendSmsService.perform_async(date, details, action)
  rescue => e
    "Failed to queue SMS: #{e.message}"
  end

end
