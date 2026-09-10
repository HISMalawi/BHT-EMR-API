# frozen_string_literal: true

class StreamingLedger < ApplicationRecord
  enum :status, {
    queued: 'queued',
    sent: 'sent',
    acknowledged: 'acknowledged',
    failed: 'failed',
    retrying: 'retrying'
  }, validate: true

  validates :stream_key, :patient_id, :program_id, :stream_date, presence: true

  before_validation :set_stream_key, on: :create

  def set_stream_key
    return if stream_key.present?
    return unless patient_id.present? && program_id.present? && stream_date.present?

    location_id = Location.current_health_center&.id
    self.stream_key = [location_id, patient_id, program_id, stream_date.iso8601].join(':')
  end
end
