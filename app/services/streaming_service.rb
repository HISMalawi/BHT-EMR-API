# frozen_string_literal: true

require 'socket'

class StreamingService
  attr_accessor :patient, :program_id, :date, :client, :config

  include Utils::JsonUtils

  def initialize(patient_id:, program_id:, date:)
    setup_remote_config
    @patient = Patient.find(patient_id)
    @program_id = program_id
    @date = date
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
      user: config['username'],
      password: config['password'],
      headers: { 'Content-Type' => 'application/json' },
      verify_ssl: false
    )
  end

  def stream_visit
    payload = to_compressed_json(
      {
        meta: {
          program_id:,
          ip_address:,
          location_id: Location.current_health_center&.id
        },
        payload: {
          raw: {
            patient: patient.as_json,
            encounters: patient.visit_data(program_id:, date:),
            current_program: patient.current_program(program_id:)
          },
          analytical: ArtService::PatientStreamBuilder.new(patient_id: patient.id, date:).build
        }
      }
    )

    Rails.logger.info("Sending stream data for #{patient.name} on #{date} to #{config['url']}")

    require 'net/http'
    uri = URI(config['url'])
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri.path, 'Content-Type' => 'application/json')
    request.body = payload.to_json
    response = http.request(request)
    Rails.logger.info("Stream response: #{response.code}")
  rescue Exception => e
    Rails.logger.error("Failed to send stream data #{e&.message}")
    raise e
  end

  def ip_address
    Socket.ip_address_list.detect(&:ipv4_private?)&.ip_address
  end
end
