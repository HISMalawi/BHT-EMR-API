# frozen_string_literal: true

# Class managing patient program details
class PatientProgramService
  def create(patient:, program:, date_enrolled: nil, location_id: nil, user: nil)
    date_enrolled ||= Time.now
    location_id ||= Location.current
    return if program.blank? || patient.blank?

    user = resolve_creator_user(user)
    creator_id = user.user_id

    patient_program = find_patient_program(patient:, program:)
    return patient_program unless patient_program.blank?

    ActiveRecord::Base.transaction do
      patient_program = PatientProgram.create(patient:, program:, date_enrolled:,
                                              location_id:, creator: creator_id)
      initial_state = initial_program_state(program)
      unless initial_state.blank?
        PatientState.create(patient_program_id: patient_program.id, start_date: date_enrolled,
                            state: initial_state.id, creator: creator_id)
      end
    end

    patient_program
  end

  def find_patient_program(patient:, program:)
    PatientProgram.where(patient:, program:).first
  end

  def initial_program_state(program)
    ProgramWorkflowState.joins(:program_workflow).where(initial: 1, terminal: 0,
                                                        program_workflow: { program_id: program.id }).first
  end

  private

  def resolve_creator_user(user)
    resolved_user = case user
                    when User
                      user
                    when Person
                      User.find_by(person_id: user.person_id)
                    else
                      resolve_user_from_identifier(user)
                    end

    resolved_user ||= User.current

    if resolved_user.blank?
      raise ActiveRecord::RecordNotFound, 'Could not resolve creator user for patient program'
    end

    resolved_user
  end

  def resolve_user_from_identifier(user)
    return if user.blank?

    if user.is_a?(Integer)
      return User.find_by(user_id: user) || User.find_by(person_id: user)
    end

    if user.respond_to?(:user_id) && user.user_id.present?
      return User.find_by(user_id: user.user_id)
    end

    if user.respond_to?(:person_id) && user.person_id.present?
      return User.find_by(person_id: user.person_id)
    end

    if user.respond_to?(:id) && user.id.present?
      return User.find_by(user_id: user.id) || User.find_by(person_id: user.id)
    end

    nil
  end
end
