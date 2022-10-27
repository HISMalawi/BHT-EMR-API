# frozen_string_literal: true

class Api::V1::HtsReportsController < ApplicationController
  before_action :validate_params
  def index
    report = service.generate_report(name: @name,
                                     type: @name,
                                     start_date: parse_date(@start_date).to_s,
                                     end_date: parse_date(@end_date).to_s)

    if report
      render json: report
    else
      render status: :no_content
    end
  end

  private

  def validate_params
    @start_date, @end_date, @name = params.require(%i[start_date end_date name])
    raise InvalidParameterError, 'start date cannot be greater than end date' if @start_date > @end_date
    raise InvalidParameterError, 'end date cannot be greater than today' if @end_date.to_date > Date.today
    raise InvalidParameterError, 'name cannot be blank' if @name.blank?
  end

  def service
    ReportService.new(program_id: 18, overwrite_mode: false)
  end
end
