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
    raise e
  end

  def lab_encounter?
    return true if respond_to?(:encounter_type) && encounter_type&.name == 'LAB ORDERS'
    return true if respond_to?(:order) && order&.order_type.id == OrderType.find_by_name('Lab').id
  rescue StandardError
    false
  end

  def patient_state_change?
    instance_of?(PatientState)
  end

  def patient_attributes_change?
    [Person, PersonAttribute, PatientIdentifier, PersonAddress].include?(self.class)
  end

  def eligible_for_streaming?
    return false unless streaming_enabled?
    patient_state_change? || \
      patient_attributes_change? || \
      lab_encounter? || \
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
    config['queue']['processing_delay_time'] || 10
  end

  def get_patient_id
    id = patient_id if respond_to?(:patient_id)
    id ||= patient_program.patient_id if respond_to?(:patient_program)
    id ||= person_id if respond_to?(:person_id)
    id ||= order.patient.patient_id if respond_to?(:order)
    id
  end

  def get_program_id
    program_id = patient_program.program_id if respond_to?(:patient_program)
    program_id ||= program_id if respond_to?(:program_id)
    program_id ||= 1
    program_id
  end

  def get_date
    date = encounter_datetime if respond_to?(:encounter_datetime)
    date ||= order.start_date if respond_to?(:order)
    date ||= obs_datetime if respond_to?(:obs_datetime)
    date ||= date_created if respond_to?(:date_created)
    date ||= Date.today
    date ||= date.strftime('%Y-%m-%d') if date.blank?

    date
  end

  def streaming_enabled?
    GlobalProperty.find_by_property('patient.streaming')&.property_value == 'active' || false
  end
end
