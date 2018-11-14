# frozen_string_literal: true

class ReportService
  ENGINES = {
    'HIV PROGRAM' => ARTService::ReportEngine
  }.freeze

  LOGGER = Rails.logger

  def initialize(program_id:)
    @program = Program.find(program_id)
  end

  def report(name, date = Date.today, kwargs = {})
    LOGGER.debug "Retrieving report, #{name}, for period starting #{date}"
    type = report_type(name)

    report = find_report(type, date)
    return report if report

    LOGGER.debug("#{name} report not found... Queueing one...")
    queue_report(type: type, date: date, **kwargs)
    nil
  end

  private

  def engine(program)
    ENGINES[program_name(program)]
  end

  def program_name(program)
    program.concept.concept_names.each do |concept_name|
      name = concept_name.name.upcase
      return name if ENGINES.include?(name)
    end
  end

  def report_type(name)
    report_type = ReportType.find_by(name: name) # TODO: Also filter by program idt
    raise NotFoundError, "Report type, #{name}, not found" unless report_type

    report_type
  end

  def find_report(type, date)
    Report.where(type: type)\
          .where('DATE(report_datetime) >= DATE(?)', date)\
          .order(:report_datetime)\
          .limit(1)[0]
  end

  def queue_report(date:, type:, **kwargs)
    kwargs[:date] = date.to_s
    kwargs[:type] = type.id
    LOGGER.debug("Queueing #{type.name} report with arguments: #{kwargs}")
    ReportJob.perform_later(engine(@program).to_s, kwargs)
  end
end
