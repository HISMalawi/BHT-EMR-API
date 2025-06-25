# frozen_string_literal: true

class ClearFinishedJob < ApplicationJob
  def perform
    self.queue_adapter = :solid_queue

    SolidQueue::Job.clear_finished_in_batches
  end
end
