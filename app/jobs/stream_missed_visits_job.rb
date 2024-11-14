class StreamMissedVisitsJob
  def perform
    StreamingService.stream_missed_visits
  end
end