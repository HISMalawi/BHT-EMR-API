# frozen_string_literal: true

require 'json'

def check_outcomes
  # Expecting a comma-separated string of patient_ids as the first argument
  patient_ids = ARGV[0]&.split(',')&.map(&:to_i) || []
  
  if patient_ids.empty?
    puts {}.to_json
    return
  end

  hiv_program = Program.find_by_name('HIV PROGRAM')
  if hiv_program.nil?
    puts {}.to_json
    return
  end

  # ============================================================================
  # DYNAMIC OUTCOME CHECK
  # Uses the patient_outcome() MySQL stored function — the same function
  # the EMR report uses — instead of looking for static PatientState records
  # that may never be written for defaulters in this database.
  # ============================================================================
  
  results = {}
  reference_date = Date.today.to_s

  # Process in batches to avoid overwhelming the DB
  patient_ids.each_slice(500) do |batch|
    union_sql = batch.map { |pid| "SELECT #{pid} AS patient_id, patient_outcome(#{pid}, '#{reference_date}') AS outcome" }.join(" UNION ALL ")
    
    rows = ActiveRecord::Base.connection.select_all(union_sql)
    rows.each do |row|
      pid = row['patient_id'].to_s
      outcome = row['outcome'].to_s

      # Return 1.0 if the stored function classifies them as Defaulted
      results[pid] = outcome.match?(/Defaulted/i) ? 1.0 : 0.0
    end
  end

  # Output the exact reality mapping to standard stream for Python
  puts results.to_json
end

check_outcomes
