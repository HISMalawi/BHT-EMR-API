# frozen_string_literal: true

class ProgramWorkflowState < RetirableRecord
  self.table_name = 'program_workflow_state'
  self.primary_key = 'program_workflow_state_id'

  belongs_to :program_workflow
  belongs_to :concept
  has_many :patient_states, foreign_key: :state

  def name
    ConceptName.find_by(concept_id: concept_id)&.name
  end

  def self.find_by_name_and_program(name:, program_id:)
    ProgramWorkflowState.joins('INNER JOIN program_workflow USING (program_workflow_id)
                                INNER JOIN concept_name ON concept_name.concept_Id = program_workflow_state.concept_id')
                        .where('program_id = ? AND name = ?', program_id, name)
                        .first
  end
end
