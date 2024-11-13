class QueuePatientForStreamingJob < ApplicationJob
  self.queue_adapter = :solid_queue

  def perform(patient_id:, program_id:, date:)
    StreamingService.new(patient_id:, program_id:, date:).stream_complete_visit
  rescue StandardError => e
    puts e.message
  end
end