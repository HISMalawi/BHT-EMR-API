module Stream
  extend ActiveSupport::Concern

  WAIT_TIME = 10_000

  included do
    after_commit  :stream, on: %i[create update]
  end

  def stream
    debugger
    visit_complete = service.visit_complete?
    if visit_complete
      QueuePatientForStreamingJob
        .set(wait: WAIT_TIME.seconds)
        .perform_later(
          patient_id:,
          program_id:,
          date:
        )
    end
  end

  def service
    WorkflowService.new(
      program_id: self.program_id, 
      patient_id: self.patient_id, 
      date: self.date.strftime('%Y-%m-%d')
    )
  end
end