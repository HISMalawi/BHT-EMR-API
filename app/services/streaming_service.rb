# frozen_string_literal: true

require 'digest'
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
      headers: { content_type: :json },
      verify_ssl: OpenSSL::SSL::VERIFY_NONE,
      open_timeout: 600,
      timeout: 600
    )
  end

  def stream_visit(ledger: nil)
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

    payload_hash = Digest::SHA256.hexdigest(payload.to_json)
    if ledger
      StreamingLedgerService.mark_sent!(ledger, payload_hash:, response_code: nil)
    end

    Rails.logger.info("Sending stream data for #{patient.name} on #{date} to #{config['url']}")

    response = client.post(payload.to_json)

    if ledger
      StreamingLedgerService.mark_acknowledged!(ledger, response_code: response.code)
    end

    response
  rescue RestClient::ExceptionWithResponse, RestClient::ServerBrokeConnection => e
    Rails.logger.error("Failed to send stream data #{e&.message}")
    if ledger
      StreamingLedgerService.mark_failed!(ledger, error_message: e.message, response_code: e.respond_to?(:http_code) ? e.http_code : nil)
    end
    raise e
  end

  def ip_address
    Socket.ip_address_list.detect(&:ipv4_private?)&.ip_address
  end
end
