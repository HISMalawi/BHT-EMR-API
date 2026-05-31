#!/usr/bin/env ruby
# frozen_string_literal: true

$stdout.sync = true
$stderr.sync = true

# bin/benchmark_cohort.rb
#
# Runs every step of the cohort build pipeline individually and reports
# how long each one takes, from slowest to fastest.
#
# Usage:
#   bundle exec rails runner bin/benchmark_cohort.rb [quarter] [options]
#
#   bundle exec rails runner bin/benchmark_cohort.rb "Q3 2024"
#   bundle exec rails runner bin/benchmark_cohort.rb "Q3 2024" --occupation=Military
#
# The script resets all temp tables before each run so timings are cold-cache.

require 'benchmark'

START_DATE = ARGV.find { |a| a !~ /^--/ && a =~ /\d{4}/ }
  &.then { |n| n.match(/Q([1-4])\s+(\d{4})/) }
  &.then { |m| Date.new(m[2].to_i, ((m[1].to_i - 1) * 3) + 1, 1) } || Date.new(2024, 7, 1)

END_DATE = START_DATE.next_month.next_month.next_month - 1
OCCUPATION = (ARGV.find { |a| a.start_with?('--occupation=') }&.split('=')&.last)

puts "=" * 70
puts "Cohort Build Benchmark"
puts "  Period    : #{START_DATE} – #{END_DATE}"
puts "  Occupation: #{OCCUPATION || 'All'}"
puts "=" * 70
puts

builder = ArtService::Reports::CohortBuilder.new

# --------------------------------------------------------------------------
# Helper: run one named step, capture wall time and MySQL profile
# --------------------------------------------------------------------------
results = []

def timed(label, results)
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  yield
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
  results << { label: label, seconds: elapsed.round(3) }
  puts "  %-55s %7.3fs" % [label, elapsed]
rescue => e
  puts "  %-55s ERROR: #{e.message}" % [label]
  results << { label: label, seconds: nil, error: e.message }
end

# --------------------------------------------------------------------------
# Phase 1: Table preparation + data loading (the "init" pipeline)
# --------------------------------------------------------------------------
puts "Phase 1 — Temp table setup & data loading"
puts "-" * 70

timed("prepare_tables (create/truncate all temp tables)", results) do
  builder.send(:prepare_tables)
end

timed("load_phase1_parallel (all 5 loads in parallel threads)", results) do
  builder.send(:load_phase1_parallel, END_DATE)
end

timed("load_data_into_temp_earliest_start_date (cohort_members + filter)", results) do
  builder.send(:load_data_into_temp_earliest_start_date, END_DATE.to_date, OCCUPATION)
end

# --------------------------------------------------------------------------
# Phase 2: Outcomes computation
# --------------------------------------------------------------------------
puts
puts "Phase 2 — Outcomes computation"
puts "-" * 70

timed("update_cum_outcome (Outcomes + MaternalStatus)", results) do
  builder.send(:update_cum_outcome, start_date: START_DATE, end_date: END_DATE)
end

# --------------------------------------------------------------------------
# Phase 3: Cohort struct population (all the report indicator queries)
# --------------------------------------------------------------------------
puts
puts "Phase 3 — Report indicator population"
puts "-" * 70

cohort_struct = ArtService::Reports::CohortStruct.new
cum_start_date = builder.send(:get_cum_start_date)
cum_start_date = START_DATE if cum_start_date.blank?
quarter_start_date = START_DATE.to_date

timed("total_registered × 3", results) do
  cohort_struct.total_registered = builder.send(:total_registered, START_DATE, END_DATE)
  cohort_struct.cum_total_registered = builder.send(:total_registered, cum_start_date, END_DATE)
  cohort_struct.quarterly_total_registered = builder.send(:total_registered, quarter_start_date, END_DATE)
end

timed("initiated_on_art_first_time × 3", results) do
  cohort_struct.initiated_on_art_first_time = builder.send(:initiated_on_art_first_time, START_DATE, END_DATE)
  cohort_struct.cum_initiated_on_art_first_time = builder.send(:initiated_on_art_first_time, cum_start_date, END_DATE)
  cohort_struct.quarterly_initiated_on_art_first_time = builder.send(:initiated_on_art_first_time, quarter_start_date, END_DATE)
end

timed("males_initiated_on_art_first_time × 2", results) do
  cohort_struct.males_initiated_on_art_first_time = builder.send(:males_initiated_on_art_first_time, START_DATE, END_DATE, cohort_struct.initiated_on_art_first_time)
  cohort_struct.cum_males_initiated_on_art_first_time = builder.send(:males_initiated_on_art_first_time, cum_start_date, END_DATE, cohort_struct.cum_initiated_on_art_first_time)
end

timed("re_initiated_on_art × 3", results) do
  cohort_struct.re_initiated_on_art = builder.send(:re_initiated_on_art, START_DATE, END_DATE)
  cohort_struct.cum_re_initiated_on_art = builder.send(:re_initiated_on_art, cum_start_date, END_DATE)
  cohort_struct.quarterly_re_initiated_on_art = builder.send(:re_initiated_on_art, quarter_start_date, END_DATE)
end

timed("transfer_in × 3", results) do
  cohort_struct.transfer_in = builder.send(:transfer_in, START_DATE, END_DATE, cohort_struct.re_initiated_on_art)
  cohort_struct.cum_transfer_in = builder.send(:transfer_in, cum_start_date, END_DATE, cohort_struct.cum_re_initiated_on_art)
  cohort_struct.quarterly_transfer_in = builder.send(:transfer_in, quarter_start_date, END_DATE, cohort_struct.quarterly_re_initiated_on_art)
end

timed("males × 3", results) do
  cohort_struct.all_males = builder.send(:males, START_DATE, END_DATE)
  cohort_struct.cum_all_males = builder.send(:males, cum_start_date, END_DATE)
  cohort_struct.quarterly_all_males = builder.send(:males, quarter_start_date, END_DATE)
end

timed("load_temp_pregnant_obs + pregnant_females × 3", results) do
  builder.send(:load_temp_pregnant_obs, cum_start_date, END_DATE)
  cohort_struct.pregnant_females_all_ages = builder.send(:pregnant_females_all_ages, START_DATE, END_DATE)
  cohort_struct.cum_pregnant_females_all_ages = builder.send(:pregnant_females_all_ages, cum_start_date, END_DATE)
  cohort_struct.quarterly_pregnant_females_all_ages = builder.send(:pregnant_females_all_ages, quarter_start_date, END_DATE)
end

timed("non_pregnant_females × 3", results) do
  cohort_struct.non_pregnant_females = builder.send(:non_pregnant_females, START_DATE, END_DATE, cohort_struct.pregnant_females_all_ages)
  cohort_struct.cum_non_pregnant_females = builder.send(:non_pregnant_females, cum_start_date, END_DATE, cohort_struct.cum_pregnant_females_all_ages)
  cohort_struct.quarterly_non_pregnant_females = builder.send(:non_pregnant_females, quarter_start_date, END_DATE, cohort_struct.cum_pregnant_females_all_ages)
end

timed("age groups at initiation × 3 each (3 groups)", results) do
  [:children_below_24_months_at_art_initiation,
   :children_24_months_14_years_at_art_initiation,
   :adults_at_art_initiation,
   :unknown_age].each do |m|
    cohort_struct.send(:"#{m}=", builder.send(m, START_DATE, END_DATE))
    cohort_struct.send(:"cum_#{m}=", builder.send(m, cum_start_date, END_DATE))
    cohort_struct.send(:"quarterly_#{m}=", builder.send(m, quarter_start_date, END_DATE))
  end
end

timed("who_stage + eligibility reasons × 3 each", results) do
  [:presumed_severe_hiv_disease_in_infants, :confirmed_hiv_infection_in_infants_pcr,
   :who_stage_two, :breastfeeding_mothers, :pregnant_women].each do |m|
    begin
      cohort_struct.send(:"#{m}=", builder.send(m, START_DATE, END_DATE))
      cohort_struct.send(:"cum_#{m}=", builder.send(m, cum_start_date, END_DATE))
      cohort_struct.send(:"quarterly_#{m}=", builder.send(m, quarter_start_date, END_DATE))
    rescue => e
      # some methods may not exist on all versions
    end
  end
end

timed("get_outcome (total_alive_and_on_art + died + defaulted)", results) do
  cohort_struct.total_alive_and_on_art = builder.send(:get_outcome, 'On antiretrovirals')
  cohort_struct.died_total            = builder.send(:get_outcome, 'Patient died')
  cohort_struct.defaulted             = builder.send(:get_outcome, 'Defaulted')
  cohort_struct.stopped_art           = builder.send(:get_outcome, 'Treatment stopped')
  cohort_struct.transfered_out        = builder.send(:get_outcome, 'Patient transferred out')
end

timed("update_tb_status", results) do
  builder.send(:update_tb_status, END_DATE)
end

timed("update_patient_side_effects", results) do
  builder.send(:update_patient_side_effects, END_DATE)
end

timed("regimen queries (Cohort::Regimens)", results) do
  ArtService::Reports::Cohort::Regimens.new(start_date: START_DATE, end_date: END_DATE).build rescue nil
end

timed("TPT (3HP + IPT)", results) do
  tpt = ArtService::Reports::Cohort::Tpt.new(START_DATE, END_DATE)
  tpt.newly_initiated_on_3hp rescue nil
  tpt.newly_initiated_on_ipt rescue nil
end

# --------------------------------------------------------------------------
# Phase 4: Adherence + pregnant/breastfeeding + CPT/IPT/FP/BP
#
# Mirrors the actual build() thread setup: start both preload threads
# immediately after update_cum_outcome (already done above), then measure
# the dependent queries as they run in production.
# --------------------------------------------------------------------------
puts
puts "Phase 4 — Adherence + maternal indicators + CPT/IPT/FP/BP"
puts "-" * 70

# Reset tmp tables so preload timings are fair
ActiveRecord::Base.connection.execute('TRUNCATE tmp_max_adherence')
ActiveRecord::Base.connection.execute('DROP TABLE IF EXISTS temp_obs_last_visit')

# Launch both preloads in background threads (exactly as build() does)
quoted_end = ActiveRecord::Base.connection.quote(END_DATE)

t_adherence_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
adherence_thread = Thread.new do
  ActiveRecord::Base.connection_pool.with_connection { builder.send(:load_tmp_max_adherence, quoted_end) }
end
obs_lv_thread = Thread.new do
  ActiveRecord::Base.connection_pool.with_connection { builder.send(:load_temp_obs_last_visit, quoted_end) }
end

# Inject the preload threads into the builder instance as build() would
builder.instance_variable_set(:@adherence_preload_thread, adherence_thread)
builder.instance_variable_set(:@obs_last_visit_thread, obs_lv_thread)

# Simulate the ~165s of other-indicator work that runs while preloads happen
# by just recording when the threads finish
timed("  [preload] tmp_max_adherence INSERT (background)", results) do
  adherence_thread.join
end
timed("  [preload] temp_obs_last_visit INSERT (background)", results) do
  # thread may already be done; join is instant if so
  obs_lv_thread.join
end
# Re-inject so latest_art_adherence / total_pregnant_women can join them
builder.instance_variable_set(:@adherence_preload_thread, adherence_thread)
builder.instance_variable_set(:@obs_last_visit_thread, obs_lv_thread)

timed("latest_art_adherence (joins adherence preload thread)", results) do
  adherent, not_adherent, unknown = builder.send(:latest_art_adherence,
                                                  cohort_struct.total_alive_and_on_art,
                                                  START_DATE, END_DATE)
  cohort_struct.patients_with_0_6_doses_missed_at_their_last_visit = adherent
  cohort_struct.patients_with_7_plus_doses_missed_at_their_last_visit = not_adherent
  cohort_struct.patients_with_unknown_adhrence = unknown
end

timed("total_pregnant_women (joins obs_last_visit preload thread)", results) do
  cohort_struct.total_pregnant_women = builder.send(:total_pregnant_women,
                                                     cohort_struct.total_alive_and_on_art,
                                                     START_DATE, END_DATE)
end

timed("total_breastfeeding_women (uses temp_obs_last_visit)", results) do
  cohort_struct.total_breastfeeding_women = builder.send(:total_breastfeeding_women,
                                                          cohort_struct.total_alive_and_on_art,
                                                          cohort_struct.total_pregnant_women,
                                                          START_DATE, END_DATE)
end

timed("total_patients_on_arvs_and_cpt", results) do
  cohort_struct.total_patients_on_arvs_and_cpt = builder.send(:total_patients_on_arvs_and_cpt,
                                                               cohort_struct.total_alive_and_on_art,
                                                               START_DATE, END_DATE)
end

timed("total_patients_on_arvs_and_ipt", results) do
  cohort_struct.total_patients_on_arvs_and_ipt = builder.send(:total_patients_on_arvs_and_ipt,
                                                               cohort_struct.total_alive_and_on_art,
                                                               START_DATE, END_DATE)
end

timed("total_patients_on_family_planning", results) do
  cohort_struct.total_patients_on_family_planning = builder.send(:total_patients_on_family_planning,
                                                                  cohort_struct.total_alive_and_on_art,
                                                                  quarter_start_date, END_DATE)
end

timed("total_patients_with_screened_bp", results) do
  patients_over_30 = builder.send(:total_patients_alive_and_on_art_above_30_years,
                                   cohort_struct.total_alive_and_on_art, END_DATE)
  cohort_struct.total_patients_with_screened_bp = builder.send(:total_patients_with_screened_bp,
                                                                patients_over_30, START_DATE, END_DATE)
end

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------
total = results.sum { |r| r[:seconds] || 0 }
puts
puts "=" * 70
puts "SUMMARY — sorted by duration (slowest first)"
puts "=" * 70
puts "  %-55s %7s  %5s" % ["Step", "Seconds", "Share"]
puts "  " + "-" * 68

results.select { |r| r[:seconds] }.sort_by { |r| -r[:seconds] }.each do |r|
  share = total > 0 ? (r[:seconds] / total * 100).round(1) : 0
  bar   = "#" * (share / 2).round
  puts "  %-55s %7.3fs  %4.1f%% %s" % [r[:label], r[:seconds], share, bar]
end

puts "  " + "-" * 68
puts "  %-55s %7.3fs  100.0%%" % ["TOTAL", total]
puts
