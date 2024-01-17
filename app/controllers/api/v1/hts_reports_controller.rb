# frozen_string_literal: true

class Api::V1::HtsReportsController < ApplicationController
  before_action :validate_params
  def index
    report = service.generate_report(name: @name,
                                     type: @name,
                                     start_date: @start_date,
                                     end_date: @end_date,
                                     quarter: @quarter,
                                     year: @year
                                    )

    if report
      render json: report
    else
      render status: :no_content
    end
  end

  def daily_stats
    render json: HTSService::Dashboard.daily_statistics(params[:start_date],params[:end_date])
  end

  private

  def validate_params
    permitted = params.permit(%i[start_date end_date name quarter year]).to_h
    @start_date, @end_date, @name, @quarter, @year = permitted.values_at(:start_date, :end_date, :name, :quarter, :year)
    if !@start_date.blank? && !@end_date.blank?
      handle_errors 'start date cannot be greater than end date', 'start_date' if @start_date > @end_date
      handle_errors 'end date cannot be greater than today', 'end_date' if @end_date.to_date > Date.today
    end
    handle_errors 'name cannot be blank', 'name' if @name.blank?
  end

  def handle_errors(message, entity)
    error = UnprocessableEntityError.new(message)
    error.add_entity(entity)
    raise error
  end

  def service
    ReportService.new(program_id: 18, overwrite_mode: false)
  end
end
