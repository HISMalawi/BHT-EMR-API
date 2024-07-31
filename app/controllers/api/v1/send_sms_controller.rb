require './app/services/immunization_service/send_sms_service'
require "uri"
require "json"
require "net/http"

class Api::V1::SendSmsController < ApplicationController
  before_action :initialize_variables, only: [:index]

  def index

    config_file = Rails.root.join('config', 'application.yml')
    config = YAML.load_file(config_file)
    sms_reminder = config.dig('development', 'sms_reminder')

    if sms_reminder == 'false'
      return render json: { message: "SMS reminder turned off" }
    end

    patient_details = patients_phone
    result = validatephone(patient_details[:cell_phone])
    if result.length == 13
      patient_details[:cell_phone] = result
      output = enqueue_sms(params[:appointment_date], patient_details)
    else
      output = result
    end
    render json: { message: output }
  end

  def show

    config_file = Rails.root.join('config', 'application.yml')
         config = YAML.load_file(config_file)       
      
      begin

         if config.key?('development')
          render json: config['development']
        else
          render json: { error: 'Development configuration not found' }, status: :not_found
        end

      rescue Errno::ENOENT
        render json: { error: 'Configuration file not found' }, status: :not_found
      end

  end

  def update
   
    config_file = Rails.root.join('config', 'application.yml')
    config = YAML.load_file(config_file)

    params.each do |key, value|

      if config['development'].key?(key)
         config['development'][key] = value
      end
      
    end

    File.open(config_file, 'w') { |f| f.write(config.to_yaml) }

    render json: config['development'], status: :ok
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

  def patients_phone
    patient_details = { demographics: {}, cell_phone: 0 }

    @patient.each do |patient|
      patient_details[:demographics] = patient
      age_in_days = (Date.today - patient[:dob]).to_i

      if age_in_days < 5840 # 18 years below get guardian phone
        patient_details[:cell_phone] = guardian_phone
      else
        patient_details[:cell_phone] = patient[:person_phone] 
      end
    end

    patient_details
  end

  def guardian_phone
    filters = params.permit %i[person_b relationship]
    relationships = service.find_relationships filters
    relationships[0].relation.try(:person_attributes)
                    .try(:find_by, person_attribute_type_id: PersonAttributeType.find_by_name('Cell Phone Number').id)
                    .try(:value)
  end

  def service
    PersonRelationshipService.new(Person.find(params[:person_id]))
  end

  def enqueue_sms(date, details)
     begin
       SendSmsService.perform_async(date, details)
     rescue => e
      "Failed to queue SMS: #{e.message}"
    end
  end

  def validatephone(phone)
    phone_pattern = /\A\+\d{12}\z/
    phone = "+265" + phone[1..] if phone.present? && phone.starts_with?('0')
    return phone if phone_pattern.match?(phone)

    unless phone.blank? || phone_pattern.match?(phone)
      return "Invalid phone number"
    end
  end
end
