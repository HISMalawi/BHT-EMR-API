# frozen_string_literal: true

class Api::V1::ProgramReportsController < ApplicationController
  def show
    report = engine.report('cohort')
    if report
      render json: report
    else
      render status: :no_content
    end
  end

  private

  def engine
    ReportService.new(program_id: params[:program_id])
  end
end
