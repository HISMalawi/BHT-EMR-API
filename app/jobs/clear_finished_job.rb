# frozen_string_literal: true

class ClearFinishedJob < ApplicationJob
  self.queue_adapter = :solid_queue
  
  def perform
    SolidQueue::Job.clear_finished_in_batches
  end
end
