# frozen_string_literal: true

class ProgramWorkflowState < RetirableRecord
  self.table_name = 'program_workflow_state'
  self.primary_key = 'program_workflow_state_id'

  belongs_to :program_workflow
  belongs_to :concept
  has_many :patient_states, foreign_key: :state

  # def self.find_state(state_id)
  #   self.find_by_sql(["SELECT * FROM `program_workflow_state` WHERE (`program_workflow_state`.`program_workflow_state_id` = ?)", state_id]).first
  # end
end
