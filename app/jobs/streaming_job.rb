class StreamingJob < ApplicationJob
  self.queue_adapter = :solid_queue

  def perform(patient_id:, program_id:, date:)
    StreamingService.new(patient_id:, program_id:, date:).stream_visit
  end
end