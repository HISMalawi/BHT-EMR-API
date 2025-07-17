# frozen_string_literal: true

module Api
  module V1
    class StreamingController < ApplicationController
      skip_before_action :authenticate

      def failed
        render json: SolidQueue::FailedExecution.all.as_json(include: :job)
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
    end
  end
end