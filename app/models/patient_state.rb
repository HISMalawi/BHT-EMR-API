# frozen_string_literal: true

class PatientState < VoidableRecord
  self.table_name = 'patient_state'
  self.primary_key = 'patient_state_id'

  belongs_to :patient_program
  belongs_to :program_workflow_state, foreign_key: :state,
                                      class_name: 'ProgramWorkflowState'

  after_save :end_program

  def name
    program_workflow_state&.name
  end

  def end_program
    # If this is the only state and it is not initial, oh well
    # If this is a terminal state then close the program

    patient_program.complete(end_date) if program_workflow_state.terminal != 0
  rescue StandardError
    nil
  end
end
