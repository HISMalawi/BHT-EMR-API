# frozen_string_literal: true

class StreamingService
  attr_accessor :patient, :program_id, :date, :client, :complete

  def initialize(patient_id:, program_id:, date:, complete:)
    setup_remote_config
    @patient = Patient.find(patient_id)
    @program_id = program_id
    @date = date
    @complete = complete
  end

  def generate_visit_data
    patient.generate_visit_data(program_id:, date:)
  end

  private_class_method def setup_remote_config
    @config = YAML.safe_load(
      File.read('config/application.yml'), aliases: true
    )['cdr']
    
    raise 'Streaming config not found or not properly set, 
           please refer to the application.yml.example'\
    if config.empty?

    @client = RestClient::Resource.new(
      config['url'],
      user: config['usernae'],
      password: config['password'],
      headers: { 'Content-Type' => 'application/json' }
    )
  end
  
  def stream_patient
    raise 'Invalid visit status' unless [true, false].include?(complete)

    payload = to_compressed_json(
      generate_visit_data\
        .merge(
          { complete: }
        ) 
    )
    client.post(payload)
  rescue RestClient::ExceptionWithResponse => e
    Rails.logger.error("Failed to send stream data", e.message)
    raise e.response
  end

  private_class_method def engine
    WorkflowService.new(
      program_id:, 
      patient_id:, 
      date:
    )
  end
end
