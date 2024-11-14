class StreamMissedVisitsJob < ApplicationJob
  def perform
    @date = Date.today - 1
    @program_id = 1
    
    missed_patients = queued_visits - todays_emr_visits

    missed_patients.each do |patient_id|
      QueuePatientForStreamingJob
          .perform_later(
            patient_id:,
            program_id: @program_id,
            date: @date.strftime('%Y-%m-%d'),
            complete: engine(patient_id).visit_complete?
          )
    end
  end

  def todays_emr_visits
    Patient.distinct.joins(:encounters)
           .where('encounter_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(@date))\
           .pluck(:patient_id)
  end

  def queued_visits
    query = ActiveRecord::Base.connection.select_all <<~SQL
      SELECT arguments from solid_queue_jobs
        WHERE DATE(created_at) = DATE("#{@date.strftime('%Y-%m-%d')}")
    SQL

    query.to_a.map do |job|
      JSON.parse(job['arguments'])['arguments']&.first['patient_id']
    end
  end

  def engine (patient_id) 
    WorkflowService.new(
      program_id: @program_id, 
      patient_id:, 
      date: @date.strftime('%Y-%m-%d')
    )
  end
end