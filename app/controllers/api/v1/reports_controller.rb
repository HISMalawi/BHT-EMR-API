class Api::V1::ReportsController < ApplicationController
  def index
    date = params.require %i[date]
    stats = service.dashboard_stats(date.first)

    if stats
      render json: stats
    else
      render status: :no_content
    end
  end

  def diagnosis
    start_date, end_date = params.require %i[start_date end_date]
    stats = service.diagnosis(start_date, end_date)

    render json: stats
  end

  private

  def service
    return @service if @service

    program_id, date = params.require %i[program_id date]

    @service = ReportService.new program_id: program_id
    @service
  end
end
