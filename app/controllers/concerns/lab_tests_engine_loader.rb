# frozen_string_literal: true

module LabTestsEngineLoader
  protected

  def engine
    program_id = params[:program_id]
    @engine ||= LabTestService.load_engine(program_id)
  end
end
