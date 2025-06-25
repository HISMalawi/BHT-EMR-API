# frozen_string_literal: true

class RetryStreamingJob < ApplicationJob
  def perform
    self.queue_adapter = :solid_queue

    SolidQueue::FailedExecution.all\
                               .each do |job|
      job.retry
      job.destroy
    end
  end
end
