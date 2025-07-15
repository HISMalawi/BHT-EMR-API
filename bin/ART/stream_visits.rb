require 'logger'

LOGGER = Logger.new($stdout)

class StreamVisit
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

# accept date as an argument
# accept patient_id as an argument

from_date = nil
patient_id = nil

args = ARGV[0]

if args
  if args.match?(/\d{4}-\d{2}-\d{2}/)
    from_date = args
  else
    patient_id = args
  end
end

if !from_date && !patient_id
  puts """
    Usage: rails runner bin/ART/stream_visits.rb <from_date> (optional)
    <from_date> - The date to start streaming from
    Example: rails runner bin/ART/stream_visits.rb 2020-01-01
    Example: rails runner bin/ART/stream_visits.rb 1
  """
  exit
end

begin
  visits = Encounter.where(program_id: 1).order(:encounter_datetime).group(:patient_id)
  visits = visits.where('encounter_datetime >= ?', from_date) if from_date
  visits = visits.where(patient_id:) if patient_id

  puts  "Streaming visits starting from #{from_date}" if from_date

  visits.pluck(:patient_id).each do |patient_id|

    p_visits = Encounter.where(patient_id:).group('DATE(encounter_datetime)').pluck('DATE(encounter_datetime)')
    p_visits.each do |date|
      StreamVisit.new(date: date.to_date&.strftime('%Y-%m-%d'), patient_id:).stream
    end

    LOGGER.info("Streamed #{p_visits.count} visits for patient #{patient_id}")
  end
rescue StandardError => e
  LOGGER.error("Failed to stream visits: #{e.message}")
end