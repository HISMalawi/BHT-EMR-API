class QueuePatientForStreamingJob < ApplicationJob
  self.queue_adapter = :solid_queue

  def perform(patient_id:, program_id:, date:, status:)
    StreamingService.new(patient_id:, program_id:, date:, status:).stream_patient
  end
end