class RetryStreamingJob < ApplicationJob  
  def perform
    SolidQueue::FailedExecution.all\
    .each do |job|
      job.retry
      job.destroy
    end
  end
end