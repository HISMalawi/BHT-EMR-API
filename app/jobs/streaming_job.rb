class StreamingJob < ApplicationJob
  self.queue_adapter = :solid_queue

  def perform(patient_id:, program_id:, date:)
    stream_date = date.to_date
    ledger = StreamingLedgerService.find_or_create!(patient_id:, program_id:, stream_date: stream_date)
    StreamingLedgerService.mark_queued!(ledger)

    StreamingService.new(patient_id:, program_id:, date: stream_date.to_s).stream_visit(ledger:)
  rescue StandardError => e
    StreamingLedgerService.mark_failed!(ledger, error_message: e.message)
    raise e
  end
end