# frozen_string_literal: true

module Api
  module V1
    class StreamingController < ApplicationController
      skip_before_action :authenticate

      def failed
        render json: SolidQueue::FailedExecution.all.as_json(include: :job)
      end

      def stats
        start_date = params[:start_date] || DateTime.now.beginning_of_day 
        end_date = params[:end_date] || DateTime.now.end_of_day

        jobs = SolidQueue::Job.where(class_name: 'StreamingJob', created_at: start_date..end_date)

        jobs_done = jobs.where("finished_at IS NOT NULL").count
        jobs_failed = jobs.joins('INNER JOIN solid_queue_failed_executions fe ON solid_queue_jobs.id = fe.job_id').count
        jobs_pending = jobs.where("finished_at IS NULL").count
        jobs_queued = jobs.joins('INNER JOIN solid_queue_ready_executions re ON solid_queue_jobs.id = re.job_id').count
        last_sync_at = SolidQueue::Job.maximum(:created_at)
        visits_since_last_sync = Encounter.all.where(program_id: 1, encounter_datetime: last_sync_at..).group(:patient_id).count().count

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