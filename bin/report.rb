# frozen_string_literal: true

require 'optparse'
require 'logger'

DEFAULT_PROGRAM = 'HIV Program'
DEFAULT_REPORT_TYPE = 'Cohort'

LOGGER = Logger.new STDOUT
Rails.logger = LOGGER
ActiveRecord::Base.logger = LOGGER

include ModelUtils

def main
  cmd_args = args

  program = program(cmd_args[:program_name] || DEFAULT_PROGRAM)
  report_type = cmd_args[:report_type] || DEFAULT_REPORT_TYPE
  start_date = parse_date(cmd_args[:start_date], Date.strptime('1900-01-01'))
  end_date = parse_date(cmd_args[:end_date])
  name = cmd_args[:name] || "#{report_type}: #{start_date} - #{end_date}"

  generate_report(program, name, report_type, start_date, end_date)
end

# Retrieves recognised command line arguments
def args
  parsed_args = {}

  parser = OptionParser.new do |option|
    option.on('--program PROGRAM_NAME') { |value| parsed_args[:program_name] = value }
    option.on('--type REPORT_TYPE') { |value| parsed_args[:report_type] = value }
    option.on('--start-date DATE') { |value| parsed_args[:start_date] = value }
    option.on('--end-date DATE') { |value| parsed_args[:end_date] = value }
  end

  parser.parse!
  parsed_args
end

def generate_report(program, report_name, report_type, start_date, end_date)
  LOGGER.info("Generating #{report_name} report for #{program.name} starting #{start_date} - #{end_date}")
  User.current = User.first
  service = ReportService.new(program_id: program.program_id,
                              immediate_mode: true,
                              overwrite_mode: true)
  service.generate_report(name: report_name, type: report_type,
                          start_date: start_date, end_date: end_date)
  LOGGER.info('Successfully generated report')
end

def parse_date(str_date, fallback = nil)
  str_date ? Date.strptime(str_date) : (fallback || Date.today)
end

main
