# frozen_string_literal: true

require 'csv'

# Rake task to diagnose why specific patients are not appearing in the
# PEPFAR Viral Load Coverage 2 report.
#
# Usage:
#   rake "art:reports:vl_discrepancy_debug[start_date,end_date]"
#   rake "art:reports:vl_discrepancy_debug[start_date,end_date,true]"   # rebuild temp tables
#
# Example:
#   rake "art:reports:vl_discrepancy_debug[2025-01-01,2025-03-31]"
#   rake "art:reports:vl_discrepancy_debug[2025-01-01,2025-03-31,true]"
#
# Output:
#   tmp/vl_discrepancy_<start_date>_<end_date>.csv

namespace :art do
  namespace :reports do
    desc 'Diagnose which gate excludes each patient from the VL Coverage PEPFAR report'
    task :vl_discrepancy_debug, %i[start_date end_date rebuild] => :environment do |_t, args|
      # ─── Patient IDs under investigation ──────────────────────────────────────
      # NOTE: 56 IDs are listed below. Add the remaining IDs from the full list of 66
      #       to complete the investigation.
      patient_ids = [
          192, 315, 1159, 1288, 2044, 4641, 5379, 6127, 6138, 6379, 6407, 6813, 7184, 7466, 7736, 7934, 8281, 8411, 8724, 8799, 9047, 9790, 10217, 10474, 10621, 13325, 15025, 15148, 15519, 15601, 16028, 21338, 512824, 515591, 523674, 529748, 552947, 559842, 567725, 592422, 592567, 595083, 596403, 599107, 600586, 600832, 602740, 605513, 606018, 606097, 606184, 606680, 606724, 607085, 607103, 607122, 607516        # ADD remaining IDs here to reach 66 total
      ].freeze

      # ─── Argument parsing ─────────────────────────────────────────────────────
      # Supports both invocation styles:
      #   rake "art:reports:vl_discrepancy_debug[2025-10-01,2025-12-31]"
      #   START_DATE=2025-10-01 END_DATE=2025-12-31 rake art:reports:vl_discrepancy_debug
      raw_start   = args[:start_date].presence || ENV['START_DATE']
      raw_end     = args[:end_date].presence   || ENV['END_DATE']
      raw_rebuild = args[:rebuild].presence    || ENV['REBUILD']

      raise ArgumentError, 'start_date is required. Use bracket syntax or START_DATE=YYYY-MM-DD' if raw_start.blank?
      raise ArgumentError, 'end_date is required. Use bracket syntax or END_DATE=YYYY-MM-DD'     if raw_end.blank?

      start_date = raw_start.to_date
      end_date   = raw_end.to_date
      rebuild    = raw_rebuild&.casecmp?('true')

      puts "═══════════════════════════════════════════════════════════════"
      puts "  VL Discrepancy Debug  |  #{start_date} – #{end_date}"
      puts "  Investigating #{patient_ids.size} patient IDs"
      puts "═══════════════════════════════════════════════════════════════"

      # ─── Step 1: Optionally rebuild temp tables ────────────────────────────────
      if rebuild
        puts "\n[1/7] Rebuilding PEPFAR cohort temp tables..."
        ArtService::Reports::CohortBuilder.new(outcomes_definition: 'pepfar')
                                          .init_temporary_tables(start_date, end_date, nil)
        puts '      Done.'
      else
        puts "\n[1/7] Skipping temp table rebuild (pass rebuild=true to force)."
      end

      conn       = ActiveRecord::Base.connection
      ids_clause = patient_ids.join(',')
      q_end      = conn.quote(end_date)
      q_start    = conn.quote(start_date)

      # ─── Step 2: Raw temp table data for Gate 1 diagnosis ─────────────────────
      puts '[2/7] Fetching raw temp table records...'

      raw_by_id = conn.select_all(<<~SQL).index_by { |r| r['patient_id'].to_i }
        SELECT
          tpo.patient_id,
          tpo.pepfar_cum_outcome,
          DATE(tpo.pepfar_outcome_date) AS pepfar_outcome_date,
          tpo.step,
          DATE(tesd.date_enrolled)     AS date_enrolled,
          DATE(tesd.earliest_start_date) AS earliest_start_date,
          LEFT(tesd.gender, 1)         AS gender,
          tesd.birthdate
        FROM temp_patient_outcomes tpo
        LEFT JOIN temp_earliest_start_date tesd ON tesd.patient_id = tpo.patient_id
        WHERE tpo.patient_id IN (#{ids_clause})
      SQL

      # ─── Step 3: Check presence in temp_max_patient_state & temp_current_medication ──
      puts '[3/7] Checking supporting temp tables...'

      in_max_state = conn.select_all(
        "SELECT patient_id FROM temp_max_patient_state WHERE patient_id IN (#{ids_clause})"
      ).map { |r| r['patient_id'].to_i }.to_set

      in_medication = conn.select_all(
        "SELECT DISTINCT patient_id FROM temp_current_medication WHERE patient_id IN (#{ids_clause})"
      ).map { |r| r['patient_id'].to_i }.to_set

      # ─── Step 4: VL order activity enrichment ─────────────────────────────────
      puts '[4/7] Fetching VL order history and results...'

      # Latest VL order per patient: order entry date, sample draw date, and whether
      # any order fell specifically inside the reporting period.
      vl_orders_by_id = conn.select_all(<<~SQL).index_by { |r| r['patient_id'].to_i }
        SELECT
          o.patient_id,
          DATE(MAX(CASE
            WHEN o.start_date >= DATE(#{ActiveRecord::Base.connection.quote(start_date)})
             AND o.start_date  < DATE(#{ActiveRecord::Base.connection.quote(end_date)}) + INTERVAL 1 DAY
            THEN o.start_date END))                                   AS vl_order_date_in_period,
          DATE(MAX(o.start_date))                                     AS latest_vl_order_date,
          DATE(MAX(COALESCE(o.discontinued_date, o.start_date)))      AS latest_sample_draw_date
        FROM orders o
        INNER JOIN concept_name cn
          ON cn.concept_id = o.concept_id
          AND cn.name IN ('Blood', 'DBS (Free drop to DBS card)', 'DBS (Using capillary tube)', 'Plasma')
          AND cn.voided = 0
        INNER JOIN order_type ot
          ON ot.order_type_id = o.order_type_id AND ot.name = 'Lab' AND ot.retired = 0
        WHERE o.patient_id IN (#{patient_ids.join(',')}) AND o.voided = 0
          AND o.start_date >= DATE(#{ActiveRecord::Base.connection.quote(end_date)}) - INTERVAL 12 MONTH
          AND o.start_date  < DATE(#{ActiveRecord::Base.connection.quote(end_date)}) + INTERVAL 1 DAY
        GROUP BY o.patient_id
      SQL

      # Latest VL result per patient (value + date), restricted to orders within the
      # same 12-month lookback window that the report uses.
      vl_results_by_id = conn.select_all(<<~SQL).index_by { |r| r['patient_id'].to_i }
        SELECT
          o.patient_id,
          cn.name AS latest_vl_result_specimen,
          CONCAT(
            COALESCE(result.value_modifier, ''),
            COALESCE(CAST(result.value_numeric AS CHAR), result.value_text, '')
          ) AS latest_vl_result,
          DATE(o.start_date) AS latest_vl_result_order_date
        FROM orders o
        INNER JOIN concept_name cn
          ON cn.concept_id = o.concept_id
          AND cn.name IN ('Blood', 'DBS (Free drop to DBS card)', 'DBS (Using capillary tube)', 'Plasma')
          AND cn.voided = 0
        INNER JOIN order_type ot
          ON ot.order_type_id = o.order_type_id AND ot.name = 'Lab' AND ot.retired = 0
        INNER JOIN obs result
          ON result.order_id = o.order_id
          AND result.concept_id IN (
              SELECT concept_id FROM concept_name WHERE name LIKE 'HIV Viral load' AND voided = 0
          )
          AND result.voided = 0
          AND (result.value_text IS NOT NULL OR result.value_numeric IS NOT NULL)
        INNER JOIN (
          SELECT o2.patient_id, MAX(o2.start_date) AS max_date
          FROM orders o2
          INNER JOIN concept_name cn2
            ON cn2.concept_id = o2.concept_id
            AND cn2.name IN ('Blood', 'DBS (Free drop to DBS card)', 'DBS (Using capillary tube)', 'Plasma')
            AND cn2.voided = 0
          INNER JOIN order_type ot2
            ON ot2.order_type_id = o2.order_type_id AND ot2.name = 'Lab' AND ot2.retired = 0
          INNER JOIN obs obs2
            ON obs2.order_id = o2.order_id
            AND obs2.concept_id IN (
                SELECT concept_id FROM concept_name WHERE name LIKE 'HIV Viral load' AND voided = 0
            )
            AND obs2.voided = 0
            AND (obs2.value_text IS NOT NULL OR obs2.value_numeric IS NOT NULL)
          WHERE o2.patient_id IN (#{patient_ids.join(',')}) AND o2.voided = 0
            AND o2.start_date >= DATE(#{ActiveRecord::Base.connection.quote(end_date)}) - INTERVAL 12 MONTH
            AND o2.start_date  < DATE(#{ActiveRecord::Base.connection.quote(end_date)}) + INTERVAL 1 DAY
          GROUP BY o2.patient_id
        ) latest ON latest.patient_id = o.patient_id AND latest.max_date = o.start_date
        WHERE o.patient_id IN (#{patient_ids.join(',')}) AND o.voided = 0
          AND o.start_date >= DATE(#{ActiveRecord::Base.connection.quote(end_date)}) - INTERVAL 12 MONTH
          AND o.start_date  < DATE(#{ActiveRecord::Base.connection.quote(end_date)}) + INTERVAL 1 DAY
        GROUP BY o.patient_id
      SQL

      # Latest VL order per patient exactly as the report consumes it. This may
      # differ from latest_vl_result when the newest sample has no result yet.
      vl_report_sample_by_id = conn.select_all(<<~SQL).index_by { |r| r['patient_id'].to_i }
        SELECT
          o.patient_id,
          o.order_id AS report_latest_order_id,
          cn.name AS report_latest_specimen,
          DATE(o.start_date) AS report_latest_order_date,
          DATE(COALESCE(o.discontinued_date, o.start_date)) AS report_latest_sample_draw_date,
          CONCAT(
            COALESCE(result.value_modifier, ''),
            COALESCE(CAST(result.value_numeric AS CHAR), result.value_text, '')
          ) AS report_latest_vl_result
        FROM orders o
        INNER JOIN order_type ot
          ON ot.order_type_id = o.order_type_id
          AND ot.name = 'Lab'
          AND ot.retired = 0
        INNER JOIN concept_name cn
          ON cn.concept_id = o.concept_id
          AND cn.name IN ('Blood', 'DBS (Free drop to DBS card)', 'DBS (Using capillary tube)', 'Plasma')
          AND cn.voided = 0
        LEFT JOIN obs result
          ON result.order_id = o.order_id
          AND result.concept_id IN (
            SELECT concept_id FROM concept_name WHERE name LIKE 'HIV Viral load' AND voided = 0
          )
          AND result.voided = 0
          AND (result.value_text IS NOT NULL OR result.value_numeric IS NOT NULL)
        INNER JOIN (
          SELECT o2.patient_id, MAX(o2.start_date) AS max_date
          FROM orders o2
          INNER JOIN order_type ot2
            ON ot2.order_type_id = o2.order_type_id
            AND ot2.name = 'Lab'
            AND ot2.retired = 0
          INNER JOIN concept_name cn2
            ON cn2.concept_id = o2.concept_id
            AND cn2.name IN ('Blood', 'DBS (Free drop to DBS card)', 'DBS (Using capillary tube)', 'Plasma')
            AND cn2.voided = 0
          WHERE o2.patient_id IN (#{patient_ids.join(',')})
            AND o2.voided = 0
            AND o2.start_date >= DATE(#{ActiveRecord::Base.connection.quote(end_date)}) - INTERVAL 12 MONTH
            AND o2.start_date  < DATE(#{ActiveRecord::Base.connection.quote(end_date)}) + INTERVAL 1 DAY
          GROUP BY o2.patient_id
        ) latest ON latest.patient_id = o.patient_id AND latest.max_date = o.start_date
        WHERE o.patient_id IN (#{patient_ids.join(',')})
          AND o.voided = 0
          AND o.start_date >= DATE(#{ActiveRecord::Base.connection.quote(end_date)}) - INTERVAL 12 MONTH
          AND o.start_date  < DATE(#{ActiveRecord::Base.connection.quote(end_date)}) + INTERVAL 1 DAY
        GROUP BY o.patient_id
      SQL

      # ─── Step 5: Run patients_on_art SQL restricted to target IDs ─────────────
      puts '[5/7] Running patients_on_art query for target patients...'

      identifier_type_subquery = PatientIdentifierType.where(
        name: GlobalPropertyService.use_filing_numbers? ? 'Filing number' : 'ARV Number'
      ).select(:patient_identifier_type_id).to_sql

      occupation_query = <<~SQL
        SELECT a.person_id, a.value
        FROM person_attribute a
        LEFT OUTER JOIN person_attribute b
          ON a.person_attribute_id = b.person_attribute_id
          AND a.date_created < b.date_created
          AND b.voided = 0
        WHERE b.person_attribute_id IS NULL
          AND a.person_attribute_type_id = 13
          AND a.voided = 0
      SQL

      patients_on_art = conn.select_all(<<~SQL).index_by { |r| r['patient_id'].to_i }
        SELECT
          cum.patient_id,
          disaggregated_age_group(e.birthdate, DATE(#{q_end})) AS age_group,
          regimen.regimen_category                              AS current_regimen,
          DATE(e.earliest_start_date)                          AS art_start_date,
          IF(cum.pepfar_cum_outcome = 'Defaulted',
             DATE(cum.pepfar_outcome_date), NULL)              AS defaulter_date,
          e.birthdate,
          LEFT(e.gender, 1)                                    AS gender,
          pid.identifier                                       AS arv_number,
          cum.pepfar_cum_outcome                               AS state,
          DATE(cum.pepfar_outcome_date)                        AS outcome_date,
          DATE(current_order.start_date)                       AS vl_order_date,
          DATE(st.start_date)                                  AS recorded_state_start_date,
          TIMESTAMPDIFF(MONTH, e.earliest_start_date, '2024-03-31') AS diff_in_months
        FROM temp_patient_outcomes cum
        INNER JOIN temp_earliest_start_date e ON e.patient_id = cum.patient_id
        INNER JOIN temp_max_patient_state st ON st.patient_id = cum.patient_id
        INNER JOIN (
          SELECT prescriptions.patient_id,
                 regimens.name AS regimen_category,
                 prescriptions.drugs,
                 prescriptions.prescription_date
          FROM (
            SELECT tcm.patient_id,
                   GROUP_CONCAT(DISTINCT tcm.drug_id ORDER BY tcm.drug_id ASC) AS drugs,
                   DATE(tcm.start_date) AS prescription_date
            FROM temp_current_medication tcm
            GROUP BY tcm.patient_id
          ) AS prescriptions
          LEFT JOIN (
            SELECT GROUP_CONCAT(drug.drug_id ORDER BY drug.drug_id ASC) AS drugs,
                   regimen_name.name AS name
            FROM moh_regimen_combination AS combo
            INNER JOIN moh_regimen_combination_drug AS drug USING (regimen_combination_id)
            INNER JOIN moh_regimen_name AS regimen_name USING (regimen_name_id)
            GROUP BY combo.regimen_combination_id
          ) AS regimens ON regimens.drugs = prescriptions.drugs
        ) regimen ON regimen.patient_id = cum.patient_id
        LEFT JOIN (#{occupation_query}) a ON a.person_id = cum.patient_id
        LEFT JOIN patient_identifier pid
          ON pid.patient_id = cum.patient_id
          AND pid.identifier_type IN (#{identifier_type_subquery})
          AND pid.voided = 0
        LEFT JOIN (
          SELECT ab.patient_id, MAX(ab.start_date) AS start_date
          FROM orders ab
          INNER JOIN concept_name
            ON concept_name.concept_id = ab.concept_id
            AND concept_name.name IN (
              'Blood', 'DBS (Free drop to DBS card)', 'DBS (Using capillary tube)', 'Plasma'
            )
            AND concept_name.voided = 0
          LEFT OUTER JOIN orders b
            ON ab.patient_id = b.patient_id
            AND ab.order_id  = b.order_id
            AND ab.start_date < b.start_date
            AND b.voided = 0
          WHERE b.patient_id IS NULL
            AND ab.voided = 0
            AND ab.order_type_id = 4
            AND ab.start_date < DATE(#{q_end}) + INTERVAL 1 DAY
          GROUP BY ab.patient_id
        ) current_order ON current_order.patient_id = cum.patient_id
        WHERE cum.step > 0
          AND e.date_enrolled < DATE(#{q_end}) + INTERVAL 1 DAY
          AND (
            cum.pepfar_cum_outcome = 'On antiretrovirals'
            OR (cum.pepfar_cum_outcome != 'On antiretrovirals' AND cum.pepfar_outcome_date >= DATE(#{q_end}) - INTERVAL 12 MONTH)
            OR (cum.pepfar_cum_outcome != 'On antiretrovirals' AND current_order.start_date >= DATE(#{q_end}) - INTERVAL 12 MONTH)
          )
          AND cum.patient_id IN (#{ids_clause})
        GROUP BY cum.patient_id
      SQL

      # ─── Step 6: Maternal status ───────────────────────────────────────────────
      puts '[6/7] Determining maternal status...'

      female_ids = patients_on_art.values
                                  .select { |p| p['gender']&.upcase == 'F' }
                                  .map    { |p| p['patient_id'].to_i }

      maternal = ArtService::Reports::MaternalStatus.new(start_date:, end_date:, occupation: nil)
      maternal.process_data

      pregnant_ids     = female_ids.empty? ? [] : maternal.pregnant_women(female_ids).map { |w| w['patient_id'].to_i }.to_set
      breastfeed_ids   = begin
        remaining = female_ids - pregnant_ids.to_a
        remaining.empty? ? [] : maternal.breast_feeding(remaining).map { |w| w['patient_id'].to_i }.to_set
      end

      # ─── Step 7: Walk every patient through all gates ─────────────────────────
      puts '[7/7] Diagnosing exclusion reasons...'

      rows = patient_ids.map do |patient_id| # rubocop:disable Metrics/BlockLength
        raw    = raw_by_id[patient_id]
        art    = patients_on_art[patient_id]
        vl_act = vl_orders_by_id[patient_id]
        vl_res = vl_results_by_id[patient_id]
        vl_rep = vl_report_sample_by_id[patient_id]

        art_start_d        = (art&.dig('art_start_date') || raw&.dig('earliest_start_date'))&.to_date
        months_on_art      = art_start_d ? ((end_date.year * 12 + end_date.month) - (art_start_d.year * 12 + art_start_d.month)) : nil
        vl_order_d         = art&.dig('vl_order_date')&.to_date
        days_since_last_vl = vl_order_d ? (end_date - vl_order_d).to_i : nil

        base = {
          patient_id:                   patient_id,
          arv_number:                   art&.dig('arv_number') || '-',
          pepfar_cum_outcome:           raw&.dig('pepfar_cum_outcome') || 'N/A',
          pepfar_outcome_date:          raw&.dig('pepfar_outcome_date'),
          step:                         raw&.dig('step'),
          date_enrolled:                raw&.dig('date_enrolled'),
          art_start_date:               art_start_d,
          months_on_art_at_end_date:    months_on_art,
          diff_in_months_report_value:  art&.dig('diff_in_months'),
          defaulter_date:               art&.dig('defaulter_date'),
          vl_order_date:                art&.dig('vl_order_date'),
          latest_sample_draw_date:      vl_act&.dig('latest_sample_draw_date'),
          days_since_last_vl_order:     days_since_last_vl,
          vl_order_in_reporting_period: vl_act&.dig('vl_order_date_in_period').present? ? 'YES' : 'NO',
          vl_order_date_in_period:      vl_act&.dig('vl_order_date_in_period'),
          report_latest_order_id:       vl_rep&.dig('report_latest_order_id'),
          report_latest_specimen:       vl_rep&.dig('report_latest_specimen') || '-',
          report_latest_order_date:     vl_rep&.dig('report_latest_order_date'),
          report_sample_draw_date:      vl_rep&.dig('report_latest_sample_draw_date'),
          report_latest_vl_result:      vl_rep&.dig('report_latest_vl_result').presence || '-',
          report_result_present:        vl_rep&.dig('report_latest_vl_result').presence ? 'YES' : 'NO',
          vl_due_date:                  nil,
          latest_vl_result_specimen:    vl_res&.dig('latest_vl_result_specimen') || '-',
          latest_vl_result:             vl_res&.dig('latest_vl_result').presence || '-',
          latest_vl_result_date:        vl_res&.dig('latest_vl_result_order_date'),
          current_regimen:              art&.dig('current_regimen') || '-',
          gender:                       art&.dig('gender') || raw&.dig('gender'),
          maternal_status:              nil,
          in_tx_curr:                   (raw&.dig('pepfar_cum_outcome') == 'On antiretrovirals') ? 'YES' : 'NO',
          in_patients_on_art:           art.present? ? 'YES' : 'NO',
          exclusion_gate:               nil,
          exclusion_reason:             nil
        }

        # ── Gate 0: Missing from temp_patient_outcomes entirely ──────────────────
        if raw.nil?
          next base.merge(exclusion_gate: 'G0',
                          exclusion_reason: 'Not found in temp_patient_outcomes — patient not processed in cohort build')
        end

        # ── Gate 1: Excluded by patients_on_art SQL WHERE / INNER JOINs ─────────
        if art.nil?
          reason = if raw['step'].to_i <= 0
                     "step=#{raw['step']}: record not fully loaded into temp tables"
                   elsif raw['date_enrolled'] &&
                         raw['date_enrolled'].to_date >= end_date + 1.day
                     "date_enrolled (#{raw['date_enrolled']}) is after end_date — enrolled too late"
                   elsif raw['pepfar_cum_outcome'] != 'On antiretrovirals' &&
                         raw['pepfar_outcome_date'] &&
                         raw['pepfar_outcome_date'].to_date < end_date - 12.months &&
                         (vl_orders_by_id[patient_id]&.dig('latest_vl_order_date').nil? ||
                          vl_orders_by_id[patient_id]['latest_vl_order_date'].to_date < end_date - 12.months)
                     "adverse outcome '#{raw['pepfar_cum_outcome']}' on #{raw['pepfar_outcome_date']} "\
                     "is more than 12 months before end_date and no recent lab order found"
                   elsif !in_max_state.include?(patient_id)
                     'No record in temp_max_patient_state — missing from INNER JOIN'
                   elsif !in_medication.include?(patient_id)
                     'No record in temp_current_medication — no active prescription; excluded by regimen INNER JOIN'
                   else
                     'Excluded by patients_on_art SQL (specific join could not be pinpointed — '\
                     'investigate manually using the patients_on_art query)'
                   end

          next base.merge(exclusion_gate: 'G1', exclusion_reason: reason)
        end

        # ── Gate 2: process_client_eligibility (Ruby checks) ────────────────────
        defaulter_date = art['defaulter_date']&.to_date
        art_start_date = art['art_start_date']&.to_date
        vl_order_date  = art['vl_order_date']&.to_date
        outcome_date   = art['outcome_date']&.to_date
        state          = art['state']
        current_regimen = art['current_regimen'].to_s
        diff_in_months  = art['diff_in_months'].to_i

        maternal_status = if pregnant_ids.include?(patient_id)
                            'FP'
                          elsif breastfeed_ids.include?(patient_id)
                            'FBf'
                          end
        base[:maternal_status] = maternal_status

        if art_start_date.nil?
          next base.merge(exclusion_gate: 'G2', exclusion_reason: 'art_start_date is blank')
        end

        if art_start_date > end_date - 6.months
          next base.merge(
            exclusion_gate:   'G2',
            exclusion_reason: "art_start_date (#{art_start_date}) is within 6 months of end_date — too new on ART"
          )
        end

        # ── Gate 3: remove_adverse_outcome_patient? ──────────────────────────────
        if state == 'On antiretrovirals'
          next base.merge(exclusion_gate: nil,
                          exclusion_reason: 'INCLUDED — currently on antiretrovirals')
        end

        last_date = vl_order_date || art_start_date

        # Pass-through: VL order is within reporting period
        if vl_order_date.present? && vl_order_date >= start_date && vl_order_date <= end_date
          next base.merge(exclusion_gate: nil,
                          exclusion_reason: "INCLUDED — VL order (#{vl_order_date}) is within reporting period")
        end

        # Determine length window
        length        = 12
        length_reason = 'standard 12-month window'

        if maternal_status == 'FP'
          length        = 6
          length_reason = 'reduced to 6 months: pregnant (FP)'
        elsif maternal_status == 'FBf'
          length        = 6
          length_reason = 'reduced to 6 months: breastfeeding (FBf)'
        elsif current_regimen.match?(/P/i)
          length        = 6
          length_reason = "reduced to 6 months: protease inhibitor regimen (#{current_regimen})"
        elsif diff_in_months < 12 && vl_order_date.nil?
          length        = 6
          length_reason = "reduced to 6 months: new on ART (#{diff_in_months} months) with no prior VL"
        end

        # Record when the next VL is/was due — useful for spotting boundary cases.
        # NOTE: diff_in_months (used above) mirrors the report's hardcoded 2024-03-31 baseline.
        #       See months_on_art_at_end_date column for the corrected figure.
        base[:vl_due_date] = (last_date + length.months).to_s

        # Pass-through: VL order within last 12 months of end_date
        if vl_order_date.present? && vl_order_date >= end_date - 12.months && vl_order_date <= end_date
          next base.merge(exclusion_gate: nil,
                          exclusion_reason: "INCLUDED — VL order (#{vl_order_date}) is within 12 months of end_date")
        end

        compare_date = (state == 'Defaulted' ? end_date : outcome_date)

        if compare_date.nil?
          next base.merge(exclusion_gate: 'G3',
                          exclusion_reason: "adverse outcome '#{state}' but outcome_date is NULL — "\
                                            "cannot evaluate window; patient excluded")
        end

        # Pass-through: window not yet expired when measured against outcome/end date
        if last_date + length.months < compare_date
          next base.merge(
            exclusion_gate:   nil,
            exclusion_reason: "INCLUDED — last_date (#{last_date}) + #{length} months (#{length_reason}) "\
                              "< compare_date (#{compare_date})"
          )
        end

        # Excluded: adverse outcome window expired
        base.merge(
          exclusion_gate:   'G3',
          exclusion_reason: "adverse outcome '#{state}': last_date (#{last_date}) + #{length} months "\
                            "(#{length_reason}) >= compare_date (#{compare_date})"
        )
      end

      # ─── Write CSV ─────────────────────────────────────────────────────────────
      output_path = Rails.root.join("tmp/vl_discrepancy_#{start_date}_#{end_date}.csv")
      CSV.open(output_path, 'w') do |csv|
        csv << rows.first.keys.map(&:to_s).map(&:upcase)
        rows.each { |row| csv << row.values }
      end

      # ─── STDOUT summary ────────────────────────────────────────────────────────
      summary = rows.group_by { |r| r[:exclusion_reason] || 'UNDETERMINED' }
                    .transform_values(&:count)
                    .sort_by { |reason, _| reason.start_with?('INCLUDED') ? 1 : 0 }

      included_count = rows.count { |r| r[:exclusion_reason]&.start_with?('INCLUDED') }
      excluded_count = rows.size - included_count

      puts "\n═══════════════════════════════════════════════════════════════"
      puts "  RESULTS  |  #{start_date} – #{end_date}"
      puts "═══════════════════════════════════════════════════════════════"
      puts "  Total investigated : #{rows.size}"
      puts "  Would be INCLUDED  : #{included_count}"
      puts "  Excluded           : #{excluded_count}"
      puts "\n  Breakdown by exclusion reason:"
      puts "  ─────────────────────────────────────────────────────────────"
      summary.each { |reason, count| puts "  %3d  %s" % [count, reason] }
      puts "═══════════════════════════════════════════════════════════════"
      puts "\n  CSV written to: #{output_path}\n\n"
    end
  end
end
