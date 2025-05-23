require 'logger'

LOGGER = Logger.new($stdout)

class StreamAllPatients
  attr_reader :date, :patient_id

  def initialize(date:, patient_id:)
    @date = date
    @patient_id = patient_id
  end

  def stream
    StreamingJob.perform_later(
      patient_id:,
      program_id: 1,
      date:
    )
  end
end

Encounter.where(program_id: 1).order(:encounter_datetime).group(:patient_id).pluck(:patient_id).each do |patient_id|
  
  visits = Encounter.where(patient_id:).group('DATE(encounter_datetime)').pluck('DATE(encounter_datetime)')
  visits.each do |date|
    StreamAllPatients.new(date: date.to_date&.strftime('%Y-%m-%d'), patient_id:).stream
  end

  LOGGER.info("Streamed #{visits.count} visits for patient #{patient_id}")
end