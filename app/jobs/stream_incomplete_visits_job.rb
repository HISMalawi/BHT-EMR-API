class StreamIncompleteVisitsJob < ApplicationJob
  self.queue_adapter = :solid_queue
  def perform
    date = (Date.today - 1)
    program_incomplete_visits(date:).each { |patient_id|  
      StreamingJob.perform_later(
          patient_id:,
          program_id:,
          date: date.strtotime('%Y-%m-%d')
        )
      }
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