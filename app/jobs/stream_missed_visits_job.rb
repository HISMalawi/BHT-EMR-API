class StreamMissedVisitsJob
  def perform
    
    # logic to find missed visits

    QueuePatientForStreamingJob
        .perform_later(
          patient_id: self.patient_id,
          program_id: self.program_id,
          date: self.encounter_datetime.strftime('%Y-%m-%d'),
          complete: true
        )
  end
end