class RetryStreamingJob < ApplicationJob  
  self.queue_adapter = :solid_queue
  def perform
    SolidQueue::FailedExecution.all\
    .each do |job|
      job.retry
      job.destroy
    end
  end
end