# frozen_string_literal: true

class StreamIncompleteVisitsJob < ApplicationJob
  self.queue_adapter = :solid_queue
  
  def perform
    date = (Date.today - 1)
    visits = program_incomplete_visits(date:)

    begin
      # connect to solid queue db
      # then start the job
      ActiveRecord::Base.establish_connection(:queue)

      visits.each do |patient_id|
        StreamingJob.perform_later(
          patient_id:,
          program_id:,
          date: date.strtotime('%Y-%m-%d')
        )
      end
    ensure
      ActiveRecord::Base.establish_connection(:primary)
    end
  end

  # TODO: make this dynamic for all programs
  def program_incomplete_visits(date:)
    ArtService::DataCleaningTool.new(
      start_date: date.beginning_of_day,
      end_date: date.end_of_day,
      tool_name: 'INCOMPLETE VISITS'
    ).results&.keys
  end
end
