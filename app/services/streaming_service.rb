class StreamingService

  attr_accessor :patient, :program_id, :date


  def initialize(patient_id:, program_id:, date:)
    @patient = Patient.find(patient_id)
    @program_id = program_id
    @date = date
  end

  def stream_complete_visit
    puts "Running stream complete visit for patient: #{@patient.name}"
    puts patient.encounters.to_json
  end

end