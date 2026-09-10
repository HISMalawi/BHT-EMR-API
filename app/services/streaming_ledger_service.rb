# frozen_string_literal: true

class StreamingLedgerService
  class << self
    def find_or_create!(patient_id:, program_id:, stream_date:, location_id: nil)
      resolved_location_id = location_id || Location.current_health_center&.id
      stream_key = build_stream_key(patient_id, program_id, stream_date, resolved_location_id)

      StreamingLedger.find_or_create_by!(stream_key:) do |ledger|
        ledger.patient_id = patient_id
        ledger.program_id = program_id
        ledger.stream_date = stream_date
        ledger.status = 'queued'
      end
    end

    def mark_queued!(ledger)
      ledger.update!(status: 'queued', sent_at: nil, acknowledged_at: nil, error_message: nil)
    end

    def mark_sent!(ledger, response_code: nil, payload_hash: nil)
      ledger.update!(
        status: 'sent',
        payload_hash: payload_hash,
        response_code: response_code,
        sent_at: Time.current,
        error_message: nil
      )
    end

    def mark_acknowledged!(ledger, response_code: nil)
      ledger.update!(
        status: 'acknowledged',
        acknowledged_at: Time.current,
        response_code: response_code,
        error_message: nil
      )
    end

    def mark_retrying!(ledger)
      ledger.update!(
        status: 'retrying',
        error_message: nil,
        retry_count: ledger.retry_count.to_i + 1
      )
    end

    def mark_failed!(ledger, error_message:, response_code: nil)
      ledger.update!(
        status: 'failed',
        error_message: error_message,
        response_code: response_code,
        retry_count: ledger.retry_count.to_i + 1
      )
    end

    def find_by_stream_key(stream_key)
      StreamingLedger.find_by(stream_key: stream_key)
    end

    def query(status: nil, start_date: nil, end_date: nil, patient_id: nil, program_id: nil, stream_key: nil)
      scope = StreamingLedger.all
      statuses = normalize_statuses(status)
      scope = scope.where(status: statuses) if statuses.present?
      scope = scope.where(patient_id: patient_id) if patient_id.present?
      scope = scope.where(program_id: program_id) if program_id.present?
      scope = scope.where(stream_key: stream_key) if stream_key.present?

      if start_date.present?
        parsed_start_date = parse_date(start_date)
        scope = scope.where('stream_date >= ?', parsed_start_date)
      end

      if end_date.present?
        parsed_end_date = parse_date(end_date)
        scope = scope.where('stream_date <= ?', parsed_end_date)
      end

      scope.order(created_at: :desc)
    end

    def build_stream_key(patient_id, program_id, stream_date, location_id = nil)
      [location_id, patient_id, program_id, stream_date.to_date.iso8601].join(':')
    end

    def replayable_streams
      StreamingLedger.where(status: %w[queued failed retrying]).order(:updated_at)
    end

    private

    def normalize_statuses(status)
      return [] if status.blank?

      Array(status).flat_map do |value|
        value.to_s.split(',').map(&:strip).reject(&:blank?)
      end.uniq
    end

    def parse_date(date_value)
      Date.parse(date_value.to_s)
    rescue Date::Error
      raise ArgumentError, "Invalid date: #{date_value}"
    end
  end
end
