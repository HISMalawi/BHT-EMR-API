# frozen_string_literal: true

class StreamingService
  attr_accessor :patient, :program_id, :date, :client

  def initialize(patient_id:, program_id:, date:)
    setup_remote_config
    @patient = Patient.find(patient_id)
    @program_id = program_id
    @date = date
  end

  def generate_visit_data
    Encounter.where(patient_id: @patient.patient_id, program_id: @program_id)\
            .where('encounter_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(@date))\
            .includes(
              %i[type location program observations],
              patient: [
                :patient_identifiers, 
                person: %i[
                  names 
                  person_attributes
                ]
              ],
              provider: [:names],
              orders: [:drug_order]
            )
  end

  def stream_complete_visit
    puts "Running stream complete visit for patient: #{@patient.name}"
    stream_patient("complete")
  end

  # complete | incomplete
  
  def stream_incomplete_visits
    stream('incomplete')
  end
  
  def stream_missed_visits
    complete = engine.visit_complete?
    return stream('incomplete') unless complete

    stream('complete')
  end

  private_class_method def setup_remote_config
    @config = YAML.safe_load(
      File.read('config/application.yml'), aliases: true
    )['cdr']
    
    raise 'Streaming config not found or not properly set, 
           please refer to the application.yml.example'\
    if config.empty?

    @client = RestClient::Resource.new(
      ['stream_user'],
      user: config['usernae'],
      password: config['password']
    )
  end
  
  private_class_method def stream_patient(status:)
    payload = to_compressed_json(
      generate_visit_data\
        .merge(
          { status: }
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
