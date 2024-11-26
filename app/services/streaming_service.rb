# frozen_string_literal: true

require 'socket'

class StreamingService
  attr_accessor :patient, :program_id, :date, :client, :complete, :config

  include Utils::JsonUtils

  def initialize(patient_id:, program_id:, date:, complete:)
    setup_remote_config
    @patient = Patient.find(patient_id)
    @program_id = program_id
    @date = date
    @complete = complete
  end

  def setup_remote_config
    @config = YAML.safe_load(
      File.read('config/application.yml'), aliases: true
    )['cdr']

    if config.empty?
      raise 'Streaming config not found or not properly set,
             please refer to the application.yml.example'
    end

    @client = RestClient::Resource.new(
      config['url'],
      user: config['usernae'],
      password: config['password'],
      headers: { 'Content-Type' => 'application/json' }
    )
  end

  def stream_patient
    raise 'Invalid visit status' unless [true, false].include?(@complete)

    payload = to_compressed_json(
      {
        meta: {
          program_id:,
          ip_address:,
          location_id: Location.current.location_id
        },
        payload: {
          complete:,
          patient: patient.as_json,
          encounters: patient.visit_data(program_id:, date:),
          current_program: patient.current_program(program_id:)
        }
      }
    )
    client.post({ payload: })
  rescue RestClient::ExceptionWithResponse => e
    Rails.logger.error('Failed to send stream data', e.message)
    raise e.response
  end

  def ip_address
    Socket.ip_address_list.detect(&:ipv4_private?)&.ip_address
  end
end
