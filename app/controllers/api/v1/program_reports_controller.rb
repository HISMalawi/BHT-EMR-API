# frozen_string_literal: true

class Api::V1::ProgramReportsController < ApplicationController
  include ModelUtils

  def show
    name = params[:name]
    type, start_date, end_date = parse_report_name(name)
    type ||= params[:id]
    start_date ||= params.require(:start_date)
    end_date ||= (params[:end_date] || Date.today.strftime('%Y-%m-%d'))

    pp({ start_date: start_date })

    report = service.generate_report(name: name,
                                     type: type,
                                     start_date: parse_date(start_date).to_s,
                                     end_date: parse_date(end_date),
                                     **extra_params)

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
    end_date = quarter_to_date(match[:quarter].to_i + 1, match[:year]).to_date - 1.days

    [match[:type], start_date, end_date.to_s]
  end

  def quarter_to_date(index, year)
    index = index.to_i
    year = year.to_i

    case index
    when 1 then "#{year}-01-01"
    when 2 then "#{year}-04-01"
    when 3 then "#{year}-07-01"
    when 4 then "#{year}-10-01"
    when 5 then "#{year + 1}-01-01" # Not sure what I might end up breaking by removing this
    else raise InvalidParameterError, "Invalid quarter: Q#{index}-#{year}"
    end
  end

  def parse_date(date)
    Date.strptime(date)
  rescue StandardError => e
    logger.warn("Failed to parse date `#{date}` due to #{e.class} - #{e}")
    raise InvalidParameterError, "Invalid date `#{date}`: #{e.message}"
  end

  def extra_params
    request.query_parameters
           .to_hash
           .reject { |param, _| %w[name start_date end_date regenerate].include?(param.downcase) }
           .transform_keys(&:to_sym)
  end
end
