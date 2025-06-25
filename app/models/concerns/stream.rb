# frozen_string_literal: true

module Stream
  extend ActiveSupport::Concern

  included do
    after_commit :stream, on: %i[create update]
  end

  def stream
    if eligible_for_streaming?
      StreamingJob.set(wait: stream_wait_time.seconds)
        .perform_later(
          patient_id: get_patient_id,
          program_id: get_program_id,
          date: get_date
        )
    end
  rescue StandardError => e
    Rails.logger.error("Error streaming: #{e.message}")
  end

  def lab_result_encounter?
    encounter_type&.name == 'LAB RESULTS'
  rescue
    false
  end
  
  def patient_state_change?
    self.class == PatientState
  end

  def patient_attributes_change?
    [Person, PersonAttribute, PatientIdentifier, PersonAddress].include?(self.class)
  end

  def eligible_for_streaming?
    return false unless streaming_enabled?

    patient_state_change? ||\
    patient_attributes_change? ||\
    lab_result_encounter? ||\
    service.visit_complete?
  end

  def service
    WorkflowService.new(
      program_id: get_program_id,
      patient_id: get_patient_id,
      date: get_date
    )
  end

  def stream_wait_time
    config = Rails.configuration.database_configuration[Rails.env]
    config = config['primary'] unless config['primary'].nil?
    config['queue']['processing_delay_time'] || 10
  end

  def get_patient_id
    id = patient_id if self.respond_to?(:patient_id)
    id ||= patient_program.patient_id if self.respond_to?(:patient_program)
    id ||= person_id if self.respond_to?(:person_id)
    id
  end

  def get_program_id
    program_id = patient_program.program_id if self.respond_to?(:patient_program)
    program_id ||= program_id if self.respond_to?(:program_id)
    program_id ||= 1
    program_id
  end

  def get_date
    date = encounter_datetime if self.respond_to?(:encounter_datetime)
    date ||= obs_datetime if self.respond_to?(:obs_datetime)
    date ||= date_created if self.respond_to?(:date_created)
    date ||= Date.today
    date.strftime('%Y-%m-%d')
  end

  def streaming_enabled?
    GlobalProperty.find_by_property('patient.streaming')&.property_value == 'active' || false 
  end
end
