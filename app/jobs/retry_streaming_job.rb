# frozen_string_literal: true

class RetryStreamingJob < ApplicationJob
  def perform
    ActiveRecord::Base.establish_connection(:queue)

    SolidQueue::FailedExecution.all\
                               .each do |job|
      job.retry
      job.destroy
    end
  end
end
