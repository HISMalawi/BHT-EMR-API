module ANCService
  class WorkflowEngine
    def initialize(program:, patient:, date:)
      @patient = patient
      @program = program
      @date = date
    end

    def next_encounter
      EncounterType.new name: 'ANC'
    end
  end
end
