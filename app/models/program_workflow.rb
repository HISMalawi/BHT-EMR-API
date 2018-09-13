# frozen_string_literal: true

class ProgramWorkflow < RetirableRecord
  self.table_name = 'program_workflow'
  self.primary_key = 'program_workflow_id'

  belongs_to :program, conditions: { retired: 0 }
  belongs_to :concept, conditions: { retired: 0 }
  has_many :program_workflow_states, conditions: { retired: 0 }
end
