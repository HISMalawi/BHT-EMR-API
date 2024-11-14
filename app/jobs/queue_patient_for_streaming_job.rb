class QueuePatientForStreamingJob < ApplicationJob
  self.queue_adapter = :solid_queue

  def perform(patient_id:, program_id:, date:, complete:)
    StreamingService.new(patient_id:, program_id:, date:, complete:).stream_patient
  end
end