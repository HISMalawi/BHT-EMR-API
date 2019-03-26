# frozen_string_literal: true

class ProgramWorkflow < RetirableRecord
  self.table_name = 'program_workflow'
  self.primary_key = 'program_workflow_id'

  belongs_to :program
  belongs_to :concept

  has_many :states, class_name: 'ProgramWorkflowState'

  def as_json(options = {})
    super(options.merge(
      include: {
        states: {
          include: {
            concept: {
              include: {
                concept_names: {}
              }
            }
          },
          methods: [:name]
        },
        concept: {
          include: {
            concept_names: {}
          }
        }
      }
    ))
  end
end
