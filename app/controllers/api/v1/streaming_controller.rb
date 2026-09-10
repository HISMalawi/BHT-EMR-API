# frozen_string_literal: true

module Api
  module V1
    class StreamingController < ApplicationController
      skip_before_action :authenticate

      def failed
        render json: SolidQueue::FailedExecution.all.as_json(include: :job)
      end

      def index
        begin
          ledgers = StreamingLedgerService.query(
            status: params[:status],
            start_date: params[:start_date],
            end_date: params[:end_date],
            patient_id: params[:patient_id],
            program_id: params[:program_id],
            stream_key: params[:stream_key]
          )

          render json: ledgers.as_json(
            only: %i[id uuid stream_key patient_id program_id stream_date status payload_hash response_code error_message sent_at acknowledged_at retry_count created_at updated_at]
          )
        rescue ArgumentError => e
          render json: { error: e.message }, status: :bad_request
        end
      end

      def stats
        jobs_done = SolidQueue::ClaimedExecution.count
        jobs_failed = SolidQueue::FailedExecution.count
        jobs_pending = SolidQueue::ReadyExecution.count
        jobs_queued = SolidQueue::ScheduledExecution.count
        last_sync_at = SolidQueue::ClaimedExecution.maximum(:created_at)
        visits_since_last_sync = Encounter.all.where(program_id: 1, encounter_datetime: last_sync_at..).group(:patient_id).count

        render json: {
          solid_queue: {
            jobs_done:,
            jobs_failed:,
            jobs_pending:,
            jobs_queued:
          },
          last_sync_at:,
          visits_since_last_sync:
        }
      end

      def ack
        stream_key = params[:stream_key].presence || params[:id].presence
        return render json: { error: 'stream_key is required' }, status: :bad_request if stream_key.blank?

        ledger = StreamingLedgerService.find_by_stream_key(stream_key)
        return render json: { error: 'stream not found' }, status: :not_found unless ledger

        response_code = params[:response_code].presence
        StreamingLedgerService.mark_acknowledged!(ledger, response_code: response_code)

        render json: {
          stream_key: ledger.stream_key,
          status: ledger.reload.status,
          acknowledged_at: ledger.acknowledged_at,
          response_code: ledger.response_code
        }
      end

      def replay
        stream_key = params[:stream_key].presence
        ledgers = if stream_key.present?
                    ledger = StreamingLedgerService.find_by_stream_key(stream_key)
                    return render json: { error: 'stream not found' }, status: :not_found unless ledger
                    [ledger]
                  else
                    StreamingLedgerService.replayable_streams
                  end

        enqueued = []
        ledgers.each do |ledger|
          next if ledger.acknowledged?

          StreamingLedgerService.mark_retrying!(ledger)
          StreamingJob.perform_later(
            patient_id: ledger.patient_id,
            program_id: ledger.program_id,
            date: ledger.stream_date.to_s
          )
          enqueued << ledger.stream_key
        end

        render json: {
          queued: enqueued,
          count: enqueued.count
        }
      end
    end
  end
end