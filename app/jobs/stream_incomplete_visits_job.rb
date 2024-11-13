class StreamingIncompleteVisitsJob
  def perform
    StreamingService.stream_incomplete_visits
  end
end