# frozen_string_literal: true

class ClearFinishedJob < ApplicationJob
  def perform
    ActiveRecord::Base.establish_connection(:queue)

    SolidQueue::Job.clear_finished_in_batches
  end
end
