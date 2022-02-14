# frozen_string_literal: true

# Class managing patient program details
class PatientProgramService
  def create(patient:, program:, date_enrolled: nil, location: nil, user: nil)
    date_enrolled ||= Time.now
    location ||= Location.current
    user ||= User.current

    patient_program = find_program(patient: patient, program: program)
    return patient_program unless patient_program.blank?

    PatientProgram.create(patient: patient, program: program, date_enrolled: date_enrolled, location: location, creator: user.id)
  end

  def find_program(patient:, program:)
    PatientProgram.where(patient: patient, program: program).first
  end
end
