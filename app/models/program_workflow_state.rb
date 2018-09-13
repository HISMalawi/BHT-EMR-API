# frozen_string_literal: true

class ProgramWorkflowState < ActiveRecord::Base
  self.table_name = 'program_workflow_state'
  self.primary_key = 'program_workflow_state_id'

  belongs_to :program_workflow, conditions: { retired: 0 }
  belongs_to :concept, conditions: { retired: 0 }

  # def self.find_state(state_id)
  #   self.find_by_sql(["SELECT * FROM `program_workflow_state` WHERE (`program_workflow_state`.`program_workflow_state_id` = ?)", state_id]).first
  # end
end
