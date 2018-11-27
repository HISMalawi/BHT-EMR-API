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
                      end_date: Date.today, kwargs: {})
    LOGGER.debug "Retrieving report, #{name}, for period #{start_date} to #{end_date}"
    type = report_type(type)

    report = @overwrite_mode ? nil : find_report(type, name, start_date, end_date)
    return report if report

    lock = self.class.acquire_report_lock(type.name, start_date, end_date)
    return nil unless lock

    LOGGER.debug("#{name} report not found... Queueing one...")
    queue_report(name: name, type: type, start_date: start_date,
                 end_date: end_date, lock: lock, **kwargs)
    nil
  end

  def self.acquire_report_lock(report_type_name, start_date, end_date)
    path = lock_file_path(report_type_name, start_date, end_date)

    if path.exist? && (File.stat(path).mtime + 12.hours) > Time.now
      LOGGER.debug("Report is locked: #{path}")
      return nil
    end

    File.open(path, 'w') do |fout|
      fout << "Locked by #{User.current.username} @ #{Time.now}"
    end

    LOGGER.debug("Report lock file created: #{path}")
    path
  end

  def self.release_report_lock(path)
    path = Pathname.new(path)
    return unless path.exist?

    File.unlink(path)
  end

  private

  def engine(program)
    ENGINES[program_name(program)].new
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
    engine(@program).find_report(type: type, name: name,
                                 start_date: start_date, end_date: end_date)
  end

  def queue_report(start_date:, end_date:, type:, lock:, **kwargs)
    kwargs[:start_date] = start_date.to_s
    kwargs[:end_date] = end_date.to_s
    kwargs[:type] = type.id
    kwargs[:user] = User.current.user_id
    kwargs[:lock] = lock.to_s

    LOGGER.debug("Queueing #{type.name} report with arguments: #{kwargs}")
    if @immediate_mode
      ReportJob.perform_now(engine(@program).to_s, **kwargs)
    else
      ReportJob.perform_later(engine(@program).to_s, **kwargs)
    end
  end

  def self.lock_file_path(report_type_name, start_date, end_date)
    Rails.root.join('tmp', "#{report_type_name}-report-#{start_date}-to-#{end_date}.lock")
  end
end
