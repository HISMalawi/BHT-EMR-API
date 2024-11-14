module Stream
  extend ActiveSupport::Concern

  WAIT_TIME = YAML.safe_load(
    File.read('config/database.yml'), aliases: true
  )[Rails.env]['queue']['processing_delay_time'] || 300

  included do
    after_commit  :stream, on: %i[create update]
  end

  def stream
    visit_complete = service.visit_complete?

    if visit_complete
      QueuePatientForStreamingJob
        .set(wait: WAIT_TIME.seconds)
        .perform_later(
          patient_id: self.patient_id,
          program_id: self.program_id,
          date: self.encounter_datetime.strftime('%Y-%m-%d'),
          complete: true
        )
    end
  rescue StandardError => e
    Rails.logger.error("Error streaming: #{e.message}")
  end

  def service
    WorkflowService.new(
      program_id: self.program_id, 
      patient_id: self.patient_id, 
      date: self.encounter_datetime.strftime('%Y-%m-%d')
    )
  end
end