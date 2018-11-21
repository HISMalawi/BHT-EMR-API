# frozen_string_literal: true

class Api::V1::ProgramReportsController < ApplicationController
  def show
    name = params.require(%i[name])
    type, start_date, end_date = parse_report_name(name)
    type ||= params.require(%i[type])
    start_date ||= params.require(%i[start_date])
    end_date ||= (params[:end_date] || Date.today.strftime('%Y-%m-%d'))

    report = service.generate_report(
      name: name,
      type: report_type(type),
      start_date: Date.strptime(start_date),
      end_date: Date.strptime(end_date)
    )

    if report
      render json: report
    else
      render status: :no_content
    end
  end

  private

  def service
    ReportService.new(program_id: params[:program_id])
  end

  def parse_report_name(name)
    match = name.match(/(?<type>\w+)\s+Q(?<quarter>[1234])\s+(?<year>\d{4})/)
    return [nil, nil, nil] unless match

    start_date = quarter_to_date(match[:quarter], match[:year])
    end_date = quarter_to_date(match[:quarter].to_i + 1, match[:year]) - 1.days

    [match[:type], start_date, end_date]
  end

  def quarter_to_date(index, year)
    sdate = [nil, "#{year}-01-01", "#{year}-04-01", "#{year}-07-01",
             "#{year}-10-01", "#{year.to_i + 1}-01-01"][index]
    Date.strptime(sdate)
  end
end
