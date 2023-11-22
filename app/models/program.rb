# frozen_string_literal: true

class Program < RetirableRecord
  self.table_name = 'program'
  self.primary_key = 'program_id'

  belongs_to :concept
  has_many :patient_programs
  has_many :program_workflows
  has_many :encounters

  validates_presence_of :concept_id, :name

  def as_json(options = {})
    super(options.merge(
      include: {
        concept: {}
      }
    ))
  end

  def state(name)
    state_concept = ConceptName.where(name:).select(:concept_id)

    state = ProgramWorkflowState.where(concept: state_concept)
                                .joins(:program_workflow)
                                .merge(program_workflows)
                                .first

    raise NotFoundError, "State '#{name}' missing in #{program.name}'s workflows" unless state

    state
  end

  # # Actually returns +Concept+s of suitable +Regimen+s for the given +weight+
  # # and this +Program+
  # def regimens(weight=nil)
  #   Regimen.program(program_id).criteria(weight).all(
  #     :select => 'concept_id',
  #     :group => 'concept_id, program_id',
  #     :include => :concept, :order => 'regimen_id').map(&:concept)
  # end
end
