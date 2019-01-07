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
end
