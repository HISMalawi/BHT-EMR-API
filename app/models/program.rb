# frozen_string_literal: true

class Program < RetirableRecord
  self.table_name = 'program'
  self.primary_key = 'program_id'

  belongs_to :concept
  has_many :patient_programs
  has_many :program_workflows
  belongs_to :encounter

  validates_presence_of :concept_id, :name

  def as_json(options = {})
    super(options.merge(
      include: {
        concept: {}
      }
    ))
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
