# frozen_string_literal: true

class Api::V1::ProgramReportsController < ApplicationController
  include ModelUtils

  def show
    name = params[:name]
    type, start_date, end_date = parse_report_name(name)
    type ||= params[:id]
    start_date ||= params.require(%i[start_date])[0]
    end_date ||= (params[:end_date] || Date.today.strftime('%Y-%m-%d'))

    report = service.generate_report(
      name: name,
      type: type,
      start_date: Date.strptime(start_date.to_s),
      end_date: Date.strptime(end_date.to_s),
      **extra_params
    )

    if report
      render json: report
    else
      render status: :no_content
    end
  end

  private

  def service
    ReportService.new(program_id: params[:program_id],
                      overwrite_mode: params[:regenerate]&.casecmp?('true'))
  end

  def parse_report_name(name)
    return [nil, nil, nil] unless name

    match = name.match(/(?<type>\w+\s+)?Q(?<quarter>[1234])\s+(?<year>\d{4})/)
    return [nil, nil, nil] unless match

    start_date = quarter_to_date(match[:quarter], match[:year])
    end_date = quarter_to_date(match[:quarter].to_i + 1, match[:year]) - 1.days

    [match[:type], start_date, end_date]
  end

  def quarter_to_date(index, year)
    index = index.to_i
    year = year.to_i
    sdate = [
      nil, "#{year}-01-01", "#{year}-04-01", "#{year}-07-01", "#{year}-10-01",
      "#{year + 1}-01-01"
    ][index]
    Date.strptime(sdate)
  end

  def extra_params
    request.query_parameters
           .to_hash
           .reject { |param, _| %w[name start_date end_date regenerate].include?(param.downcase) }
           .transform_keys(&:to_sym)
  end
end
