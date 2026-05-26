# frozen_string_literal: true

require 'json'

# Rake tasks for capturing and comparing ART cohort report output.
# Used to verify that optimisation changes do not alter report values.
#
# Workflow:
#   1. On the stable branch, capture a baseline snapshot:
#        rake "art:cohort:snapshot[2025-01-01,2025-03-31]"
#
#   2. Switch to the optimisation branch, capture a second snapshot:
#        rake "art:cohort:snapshot[2025-01-01,2025-03-31]"
#
#   3. Compare:
#        rake "art:cohort:compare[tmp/cohort_snapshot_..._development.json,tmp/cohort_snapshot_..._chore-cohort_optimisation.json]"
#
# Snapshots are written to tmp/cohort_snapshot_<start>_<end>_<git_branch>.json

namespace :art do
  namespace :cohort do
    desc 'Capture a cohort report snapshot to tmp/. Args: start_date, end_date, occupation (optional)'
    task :snapshot, %i[start_date end_date occupation] => :environment do |_t, args|
      start_date = args[:start_date] or raise ArgumentError, 'start_date is required (YYYY-MM-DD)'
      end_date   = args[:end_date]   or raise ArgumentError, 'end_date is required (YYYY-MM-DD)'
      occupation = args[:occupation] || ''

      start_date = Date.parse(start_date)
      end_date   = Date.parse(end_date)

      branch = `git rev-parse --abbrev-ref HEAD 2>/dev/null`.strip.gsub(%r{[^a-zA-Z0-9._-]}, '-')
      filename = Rails.root.join('tmp', "cohort_snapshot_#{start_date}_#{end_date}_#{branch}.json")

      puts "Building cohort #{start_date} -> #{end_date} (occupation: #{occupation.presence || 'all'})..."
      puts 'This will take several minutes on a large site.'

      cohort_struct = ArtService::Reports::CohortStruct.new
      builder = ArtService::Reports::CohortBuilder.new(outcomes_definition: 'moh')
      builder.build(cohort_struct, start_date, end_date, occupation)

      snapshot = cohort_serialize(cohort_struct)
      File.write(filename, JSON.pretty_generate(snapshot))

      puts "\nSnapshot saved to: #{filename}"
      puts "Total fields captured: #{snapshot.size}"
    end

    desc 'Compare two cohort snapshots. Args: file_a (baseline), file_b (optimised)'
    task :compare, %i[file_a file_b] => :environment do |_t, args|
      file_a = args[:file_a] or raise ArgumentError, 'file_a (baseline snapshot) is required'
      file_b = args[:file_b] or raise ArgumentError, 'file_b (optimised snapshot) is required'

      raise ArgumentError, "File not found: #{file_a}" unless File.exist?(file_a)
      raise ArgumentError, "File not found: #{file_b}" unless File.exist?(file_b)

      puts "Baseline : #{file_a}"
      puts "Optimised: #{file_b}"
      puts

      a = JSON.parse(File.read(file_a))
      b = JSON.parse(File.read(file_b))

      all_keys = (a.keys | b.keys).sort
      diffs = []

      all_keys.each do |field|
        val_a = a[field]
        val_b = b[field]
        next if cohort_values_equal?(val_a, val_b)

        diffs << { field: field, baseline: val_a, optimised: val_b }
      end

      if diffs.empty?
        puts "All #{all_keys.size} fields match. No regressions detected."
      else
        puts "#{diffs.size} field(s) differ:\n\n"
        diffs.each do |d|
          description = ArtService::Reports::CohortStruct::FIELD_DESCRIPTIONS[d[:field].to_sym] || d[:field]
          puts "  FIELD    : #{d[:field]}"
          puts "  LABEL    : #{description}"
          puts "  BASELINE : #{cohort_format_value(d[:baseline])}"
          puts "  OPTIMISED: #{cohort_format_value(d[:optimised])}"
          puts
        end
        exit 1
      end
    end
  end
end

# Converts a CohortStruct into a plain Hash suitable for JSON serialization.
# Arrays of patient data are reduced to sorted patient_id lists so comparison
# is order-independent.
def cohort_serialize(cohort_struct)
  ArtService::Reports::CohortStruct::FIELD_DESCRIPTIONS.each_with_object({}) do |(field, _), result|
    result[field.to_s] = cohort_normalize_value(cohort_struct.public_send(field))
  end
end

def cohort_normalize_value(val)
  case val
  when Array then val.map { |item| cohort_extract_id(item) }.compact.sort
  when Hash  then val.transform_values { |v| cohort_normalize_value(v) }
  when Integer, Float, String, NilClass, TrueClass, FalseClass then val
  else val.to_s
  end
end

def cohort_extract_id(item)
  case item
  when Integer then item
  when String  then item.to_i
  when Hash    then (item['patient_id'] || item['person_id'] || item.values.first).to_i
  else item.respond_to?(:patient_id) ? item.patient_id.to_i : item.to_i
  end
end

# Order-independent equality for arrays, exact equality for scalars.
def cohort_values_equal?(a, b)
  return a == b unless a.is_a?(Array) || b.is_a?(Array)

  Array(a).sort == Array(b).sort
end

def cohort_format_value(val)
  return val.inspect unless val.is_a?(Array)
  return '[]' if val.empty?

  "(#{val.size} patients) #{val.first(5).inspect}#{val.size > 5 ? ' ...' : ''}"
end
