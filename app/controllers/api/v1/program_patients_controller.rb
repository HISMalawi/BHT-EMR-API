class Api::V1::ProgramPatientsController < ApplicationController
  before_action :load_engine

  def show
    render json: @engine.patient(params[:id])
  end

  protected

  def load_engine
    @engine = ProgramPatientsService.load_engine params[:program_id]
  end
end
