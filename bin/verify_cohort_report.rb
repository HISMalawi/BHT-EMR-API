#!/usr/bin/env ruby
# frozen_string_literal: true

# verify_cohort_report.rb
#
# Snapshot and compare cohort report values to verify code changes don't alter results.
#
# Usage:
#   # 1. Before making changes, save a baseline snapshot:
#   bundle exec rails runner bin/verify_cohort_report.rb snapshot Q3 2024
#
#   # 2. After making changes, regenerate and compare:
#   bundle exec rails runner bin/verify_cohort_report.rb compare Q3 2024
#
#   # 3. Regenerate without snapshotting (just runs the report):
#   bundle exec rails runner bin/verify_cohort_report.rb regenerate Q3 2024
#
# Options (passed as extra args after the quarter name):
#   --occupation=Military   Filter by occupation (default: none)
#   --snapshot-dir=PATH     Directory to save snapshots (default: tmp/cohort_snapshots)

require 'json'
require 'fileutils'
require 'optparse'

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
mode = ARGV.shift&.downcase
if mode.nil? || !%w[snapshot compare regenerate].include?(mode)
  warn "Usage: bundle exec rails runner bin/verify_cohort_report.rb <snapshot|compare|regenerate> <quarter> [year] [options]"
  warn "  e.g. bundle exec rails runner bin/verify_cohort_report.rb snapshot Q3 2024"
  exit 1
end

options = { occupation: nil, snapshot_dir: 'tmp/cohort_snapshots' }
opt_parser = OptionParser.new do |opts|
  opts.on('--occupation=OCC')    { |v| options[:occupation] = v }
  opts.on('--snapshot-dir=DIR')  { |v| options[:snapshot_dir] = v }
end

remaining = opt_parser.order(ARGV)
quarter_name = remaining.join(' ').strip

if quarter_name.empty?
  warn "Error: quarter name required, e.g. 'Q3 2024'"
  exit 1
end

FileUtils.mkdir_p(options[:snapshot_dir])

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

require 'date'

def parse_quarter(name)
  match = name.match(/(?<type>\w+\s+)?Q(?<quarter>[1234])\s+(?<year>\d{4})/)
  raise ArgumentError, "Cannot parse quarter from '#{name}'" unless match

  year  = match[:year].to_i
  q     = match[:quarter].to_i
  start_month = ((q - 1) * 3) + 1
  start_date  = Date.new(year, start_month, 1)
  end_date    = start_date.next_month.next_month.next_month - 1
  [match[:type]&.strip, start_date, end_date]
end

def snapshot_file(snapshot_dir, quarter_name, occupation)
  slug = quarter_name.downcase.gsub(/\s+/, '_')
  slug += "_#{occupation.downcase}" if occupation
  File.join(snapshot_dir, "cohort_#{slug}.json")
end

def fetch_report_from_db(name, start_date, end_date, occupation)
  report = Report.where(name: "#{name} #{occupation}",
                        start_date: start_date,
                        end_date: end_date)
                 .order(date_created: :desc)
                 .first
  return nil unless report

  values = ReportValue.where(report_design_id: report.id).map do |rv|
    raw = rv.contents
    contents = raw.is_a?(String) ? raw.strip : raw.to_s
    [rv.name, contents]
  end.sort_by(&:first).to_h

  { 'report_name' => report.name,
    'start_date'  => report.start_date.to_s,
    'end_date'    => report.end_date.to_s,
    'date_created' => report.date_created.to_s,
    'values'      => values }
end

def run_report(quarter_name, start_date, end_date, occupation)
  puts "Regenerating cohort report for '#{quarter_name}' (#{start_date} – #{end_date})…"
  t0 = Time.now

  # rails runner has no request context, so User.current is nil.
  # Set it to any active user so save_report can write creator fields.
  User.current ||= User.first

  cohort = ArtService::Reports::ArtCohort.new(
    name: quarter_name,
    type: ReportType.find_by_name('Cohort'),
    start_date: start_date.to_s,
    end_date:   end_date.to_s,
    occupation: occupation
  )

  # Destroy cached copy so we always get a fresh run
  existing = Report.where(name: "#{quarter_name} #{occupation}",
                          start_date: start_date,
                          end_date: end_date)
  existing.each(&:destroy) if existing.any?

  cohort.build_report

  elapsed = (Time.now - t0).round(1)
  puts "Done in #{elapsed}s"
end

def diff_values(baseline, current)
  added    = current.keys - baseline.keys
  removed  = baseline.keys - current.keys
  changed  = (baseline.keys & current.keys).select { |k| baseline[k] != current[k] }

  { added: added, removed: removed, changed: changed.map { |k|
    { name: k, before: baseline[k], after: current[k] }
  }}
end

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
_type, start_date, end_date = parse_quarter(quarter_name)
occupation   = options[:occupation]
snap_path    = snapshot_file(options[:snapshot_dir], quarter_name, occupation)

case mode
when 'snapshot'
  puts "Fetching stored report for '#{quarter_name}' from database…"
  data = fetch_report_from_db(quarter_name, start_date, end_date, occupation)

  if data.nil?
    warn "No saved report found for '#{quarter_name}' (#{start_date} – #{end_date})."
    warn "Run 'regenerate' first to build the report, then snapshot it."
    exit 1
  end

  File.write(snap_path, JSON.pretty_generate(data))
  puts "Snapshot saved to #{snap_path} (#{data['values'].size} indicators, generated #{data['date_created']})"

when 'regenerate'
  run_report(quarter_name, start_date, end_date, occupation)
  puts "Run 'snapshot' to save a baseline, or 'compare' to diff against a saved baseline."

when 'compare'
  unless File.exist?(snap_path)
    warn "No baseline snapshot found at #{snap_path}."
    warn "Run 'snapshot' first to capture a baseline before making changes."
    exit 1
  end

  baseline = JSON.parse(File.read(snap_path))
  puts "Baseline: #{snap_path} (#{baseline['values'].size} indicators, captured #{baseline['date_created']})"

  puts "Regenerating report for comparison…"
  run_report(quarter_name, start_date, end_date, occupation)

  puts "Fetching newly generated report…"
  current_data = fetch_report_from_db(quarter_name, start_date, end_date, occupation)
  if current_data.nil?
    warn "Could not fetch newly generated report from database."
    exit 1
  end

  diff = diff_values(baseline['values'], current_data['values'])

  if diff[:added].empty? && diff[:removed].empty? && diff[:changed].empty?
    puts "\n✓ PASS — All #{baseline['values'].size} indicators match the baseline exactly."
    exit 0
  else
    puts "\n✗ FAIL — Report values differ from baseline:"

    unless diff[:added].empty?
      puts "\n  NEW indicators (#{diff[:added].size}):"
      diff[:added].each { |k| puts "    + #{k}: #{current_data['values'][k]}" }
    end

    unless diff[:removed].empty?
      puts "\n  REMOVED indicators (#{diff[:removed].size}):"
      diff[:removed].each { |k| puts "    - #{k}: #{baseline['values'][k]}" }
    end

    unless diff[:changed].empty?
      max_len = diff[:changed].map { |c| c[:name].length }.max
      puts "\n  CHANGED indicators (#{diff[:changed].size}):"
      puts "  #{'Indicator'.ljust(max_len)}  Before  After"
      puts "  #{'-' * max_len}  ------  -----"
      diff[:changed].each do |c|
        puts "  #{c[:name].ljust(max_len)}  #{c[:before].to_s.rjust(6)}  #{c[:after]}"
      end
    end

    exit 1
  end
end
