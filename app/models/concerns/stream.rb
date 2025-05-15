# frozen_string_literal: true

module Stream
  extend ActiveSupport::Concern

  WAIT_TIME = YAML.safe_load(
    File.read('config/database.yml'), aliases: true
  )[Rails.env]['queue']['processing_delay_time'] || 300

  included do
    after_commit :stream, on: %i[create update]
  end

  def stream
    if eligible_for_streaming?
      QueuePatientForStreamingJob
        .set(wait: WAIT_TIME.seconds)
        .perform_later(
          patient_id:,
          program_id:,
          date: encounter_datetime.strftime('%Y-%m-%d'),
          complete: true
        )
    end
  rescue StandardError => e
    Rails.logger.error("Error streaming: #{e.message}")
  end

  def lab_result_encounter?
    encounter_type.name == 'LAB RESULTS'
  end

  def eligible_for_streaming?
    service.visit_complete? || lab_result_encounter?
  end

  def service
    WorkflowService.new(
      program_id:,
      patient_id:,
      date: encounter_datetime.strftime('%Y-%m-%d')
    )
  end
end
