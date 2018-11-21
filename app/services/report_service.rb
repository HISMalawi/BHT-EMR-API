# frozen_string_literal: true

class ReportService
  ENGINES = {
    'HIV PROGRAM' => ARTService::ReportEngine
  }.freeze

  LOGGER = Rails.logger

  def initialize(program_id:, immediate_mode: false, overwrite_mode: false)
    @program = Program.find(program_id)
    @immediate_mode = immediate_mode
    @overwrite_mode = overwrite_mode
  end

  def generate_report(name:, type:, start_date: Date.strptime('1900-01-01'),
                      end_date: Date.today, overwrite: false, kwargs: {})
    LOGGER.debug "Retrieving report, #{name}, for period #{start_date} to #{end_date}"
    type = report_type(type)

    report = find_report(type, name, start_date, end_date)
    return report if report && !@overwrite_mode

    LOGGER.debug("#{name} report not found... Queueing one...")
    queue_report(name: name, type: type, start_date: start_date,
                 end_date: end_date, **kwargs)
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
    report_type = ReportType.find_by(name: name) # TODO: Also filter by program id
    raise NotFoundError, "Report type, #{name}, not found" unless report_type

    report_type
  end

  def find_report(type, name, start_date, end_date)
    Report.where(type: type, name: name, start_date: start_date, end_date: end_date)\
          .order(date_created: :desc)\
          .first
  end

  def queue_report(start_date:, end_date:, type:, **kwargs)
    kwargs[:start_date] = start_date.to_s
    kwargs[:end_date] = end_date.to_s
    kwargs[:type] = type.id
    kwargs[:user] = User.current.user_id

    LOGGER.debug("Queueing #{type.name} report with arguments: #{kwargs}")
    if @immediate_mode
      ReportJob.perform_now(engine(@program).to_s, **kwargs)
    else
      ReportJob.perform_later(engine(@program).to_s, **kwargs)
    end
  end
end
