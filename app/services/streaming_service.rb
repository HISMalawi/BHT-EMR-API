# frozen_string_literal: true

class StreamingService
  attr_accessor :patient, :program_id, :date

  def initialize(patient_id:, program_id:, date:)
    @patient = Patient.find(patient_id)
    @program_id = program_id
    @date = date
  end

  def generate_visit_data
    Encounter.where(patient_id: @patient.patient_id, program_id: @program_id)\
            .where('encounter_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(@date))\
            .includes(
              %i[type location program observations],
              patient: [
                :patient_identifiers, 
                person: %i[
                  names 
                  person_attributes
                ]
              ],
              provider: [:names],
              orders: [:drug_order]
            )
  end

  def stream_complete_visit
    puts "Running stream complete visit for patient: #{@patient.name}"
    encounters =  generate_visit_data
    # raise encounters.inspect
  end

  def stream_patient; end

  def stream_incomplete_visits; end

  def stream_missed_visits; end
end
