# frozen_string_literal: true

# Manage patient's program state.
class PatientStateService
  # Returns the patient's current state in the given program.
  def find_patient_state(program, patient, ref_date = Date.today)
    patient_program = find_patient_program(program, patient, ref_date)
    find_patient_state_impl(patient_program, ref_date)
  end

  def all_patient_states(program, patient, ref_date)
    PatientState.where(patient_program: find_patient_program(program, patient, ref_date))\
                .where('start_date <= DATE(?)', ref_date)
  end

  def create_patient_state(program, patient, state, start_date)
    patient_program = find_patient_program(program, patient, start_date)
    current_patient_state = find_patient_state_impl(patient_program, start_date)

    close_patient_state(current_patient_state, start_date) if current_patient_state

    PatientState.create patient_program:,
                        state:,
                        start_date:,
                        end_date: nil
  end

  def void_state(patient_state, reason)
    void_encounter(patient_state, reason) if patient_state.name == 'Patient transferred out'
    patient_state.void(reason)
  end

  private

  def void_encounter(patient_state, reason)
    encounters = Encounter.where("patient_id = #{patient_state.patient_program.patient.id}
                                AND program_id = #{patient_state.patient_program.program.id}
                                AND encounter_type = #{EncounterType.find_by_name('EXIT FROM HIV CARE').id}
                                AND date_created = '#{patient_state.date_created}'")
    encounters.each do |encounter|
      encounter.void(reason)
    end
  end

  def find_patient_program(program, patient, ref_date)
    patient_program = PatientProgram.where(program:, patient:)\
                                    .where('DATE(date_enrolled) <= ?', ref_date)\
                                    .last

    unless patient_program
      raise NotFoundError,
            "PatientProgram(patient_id = #{patient&.id}, program_id = #{program&.id}, date_enrolled <= #{ref_date}) not found"
    end

    patient_program
  end

  def close_patient_state(patient_state, end_date)
    patient_state.end_date = end_date
    patient_state.save
  end

  # Returns the patient's state on this given date
  def find_patient_state_impl(patient_program, date)
    PatientState.where(patient_program:)\
                .where('start_date <= ? AND end_date IS NULL', date)\
                .last
  end
end
