# frozen_string_literal: true

class StreamingService
  attr_accessor :patient, :program_id, :date

  def initialize(patient_id:, program_id:, date:)
    @patient = Patient.find(patient_id)
    @program_id = program_id
    @date = date
  end

  def stream_complete_visit
    puts "Running stream complete visit for patient: #{@patient.name}"
      # encounters =  patient.encounters.to_json
      # raise encounters.inspect

      # encounters
      # obs
    # patientiddemographics
    # site data {id and ip addr}
    # orders
      # lab
      # drug
  end

  def stream_patient; end

  def stream_incomplete_visits; end
end
