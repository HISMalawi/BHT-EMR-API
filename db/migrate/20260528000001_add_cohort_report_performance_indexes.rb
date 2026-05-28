# frozen_string_literal: true

# Adds indexes to optimize the ART Cohort Report queries.
#
# Identified gaps (confirmed via EXPLAIN against the mpc database):
#
#   1. patient_program  – single-column (program_id) scan of 138k+ rows; voided
#      is never considered until a post-scan filter.
#   2. patient_state    – single-column (state) scan of 148k+ rows; voided/
#      start_date applied as late filters.
#   3. orders           – single-column (order_type_id) scan of 1.8 M rows with
#      "Using temporary" for load_temp_order_details.
#   4. obs (concept 6987, adherence) – index_merge on 1.64 M rows; no composite
#      covers (concept_id, voided, obs_datetime).
#   5. obs (concept 2516, ART start date) – index_merge on 33k rows; same gap.
#   6. encounter        – single-column (encounter_type) scan of 144k rows for
#      the load_art_start_date query (needs program_id + voided + datetime).
#   7. person_attribute – single-column (person_attribute_type_id) scan of 258k
#      rows; voided never part of the index.
#
class AddCohortReportPerformanceIndexes < ActiveRecord::Migration[6.1]
  def up
    # -----------------------------------------------------------------------
    # 1. patient_program
    #    Queries: load_data_into_temp_cohort_members_table,
    #             load_temp_other_patient_types,
    #             load_temp_register_start_date_table
    #    Pattern: WHERE program_id = 1 AND voided = 0
    # -----------------------------------------------------------------------
    unless index_exists?(:patient_program, %i[program_id voided patient_id],
                         name: 'idx_pp_program_voided_patient')
      add_index :patient_program, %i[program_id voided patient_id],
                name: 'idx_pp_program_voided_patient'
    end

    # -----------------------------------------------------------------------
    # 2. patient_state
    #    Queries: load_data_into_temp_cohort_members_table
    #    Pattern: JOIN patient_program ON patient_program_id
    #             WHERE state = 7 AND voided = 0 AND start_date IS NOT NULL
    # -----------------------------------------------------------------------
    unless index_exists?(:patient_state,
                         %i[patient_program_id state voided start_date],
                         name: 'idx_ps_ppid_state_voided_start')
      add_index :patient_state, %i[patient_program_id state voided start_date],
                name: 'idx_ps_ppid_state_voided_start'
    end

    # -----------------------------------------------------------------------
    # 3. orders – load_temp_order_details
    #    Pattern: WHERE order_type_id = 1 AND voided = 0
    #             AND start_date BETWEEN ... GROUP BY patient_id
    #    (Replaces ineffective single-column type_of_order index for this path)
    # -----------------------------------------------------------------------
    unless index_exists?(:orders,
                         %i[order_type_id voided start_date patient_id],
                         name: 'idx_orders_type_voided_start_patient')
      add_index :orders, %i[order_type_id voided start_date patient_id],
                name: 'idx_orders_type_voided_start_patient'
    end

    # -----------------------------------------------------------------------
    # 4. orders – IPT / CPT queries (total_patients_on_arvs_and_ipt/cpt)
    #    Pattern: WHERE concept_id IN (...) AND patient_id IN (...)
    #             AND start_date BETWEEN ... AND voided = 0
    # -----------------------------------------------------------------------
    unless index_exists?(:orders,
                         %i[concept_id voided patient_id start_date],
                         name: 'idx_orders_concept_voided_patient_start')
      add_index :orders, %i[concept_id voided patient_id start_date],
                name: 'idx_orders_concept_voided_patient_start'
    end

    # -----------------------------------------------------------------------
    # 5. obs – concept_id=6987 (Drug order adherence / load_tmp_max_adherence)
    #    Pattern: WHERE concept_id = 6987 AND voided = 0
    #             AND obs_datetime < ... AND (value_numeric IS NOT NULL OR ...)
    #    Current plan: index_merge on 1.64 M rows – very slow.
    # -----------------------------------------------------------------------
    unless index_exists?(:obs,
                         %i[concept_id voided obs_datetime person_id order_id],
                         name: 'idx_obs_adherence_lookup')
      add_index :obs, %i[concept_id voided obs_datetime person_id order_id],
                name: 'idx_obs_adherence_lookup'
    end

    # -----------------------------------------------------------------------
    # 6. obs – concept_id=2516 (ART start date / load_art_start_date,
    #          load_temp_art_start_date_by_enrollment)
    #    Pattern: WHERE concept_id = 2516 AND voided = 0
    #             AND value_datetime IS NOT NULL AND value_datetime < ...
    #    Current plan: index_merge on 33k rows.
    # -----------------------------------------------------------------------
    unless index_exists?(:obs,
                         %i[concept_id voided value_datetime person_id],
                         name: 'idx_obs_art_start_date_lookup')
      add_index :obs, %i[concept_id voided value_datetime person_id],
                name: 'idx_obs_art_start_date_lookup'
    end

    # -----------------------------------------------------------------------
    # 7. obs – concept_id=7563 (Reason for starting ART)
    #    Pattern: WHERE concept_id = 7563 AND voided = 0 AND obs_datetime < ...
    #             PARTITION BY person_id ORDER BY obs_datetime DESC
    #    Current plan: skip scan on idx_obs_reporting – avoids a sort but still
    #    suboptimal for the window function.
    # -----------------------------------------------------------------------
    unless index_exists?(:obs,
                         %i[concept_id voided person_id obs_datetime],
                         name: 'idx_obs_reason_art_lookup')
      add_index :obs, %i[concept_id voided person_id obs_datetime],
                name: 'idx_obs_reason_art_lookup'
    end

    # -----------------------------------------------------------------------
    # 8. encounter – load_art_start_date
    #    Pattern: WHERE encounter_type = 9 AND program_id = 1 AND voided = 0
    #             AND encounter_datetime < ...
    #    Current plan: single-column encounter_type_id scan of 144k rows.
    # -----------------------------------------------------------------------
    unless index_exists?(:encounter,
                         %i[encounter_type program_id voided encounter_datetime patient_id],
                         name: 'idx_enc_type_program_voided_datetime')
      add_index :encounter,
                %i[encounter_type program_id voided encounter_datetime patient_id],
                name: 'idx_enc_type_program_voided_datetime'
    end

    # -----------------------------------------------------------------------
    # 9. encounter – drug_refills_and_external_consultation_list
    #    Pattern: WHERE patient_id = ? AND encounter_type = ?
    #             AND voided = 0 AND encounter_datetime < ...
    #    Existing idx_person_encounters (patient_id, encounter_type) misses
    #    voided and encounter_datetime, causing a post-filter on many rows.
    # -----------------------------------------------------------------------
    unless index_exists?(:encounter,
                         %i[patient_id encounter_type voided encounter_datetime],
                         name: 'idx_enc_patient_type_voided_datetime')
      add_index :encounter,
                %i[patient_id encounter_type voided encounter_datetime],
                name: 'idx_enc_patient_type_voided_datetime'
    end

    # -----------------------------------------------------------------------
    # 10. person_attribute – current_occupation_query
    #     Pattern: WHERE person_attribute_type_id = ? AND voided = 0
    #     Current plan: single-column scan of 258k rows.
    # -----------------------------------------------------------------------
    unless index_exists?(:person_attribute,
                         %i[person_attribute_type_id voided person_id],
                         name: 'idx_pa_type_voided_person')
      add_index :person_attribute,
                %i[person_attribute_type_id voided person_id],
                name: 'idx_pa_type_voided_person'
    end

    # -----------------------------------------------------------------------
    # 11. obs – value_drug lookup for load_temp_art_start_date_by_enrollment
    #     step 3 (ARV dispensation fallback).
    #     Pattern: WHERE concept_id = #{dispensation_concept_id}
    #              AND voided = 0 AND obs_datetime < ...
    #     GROUP BY person_id  –  INNER JOIN drug ON value_drug
    #     Existing idx_obs_drug_lookup leads with person_id, not concept_id.
    # -----------------------------------------------------------------------
    unless index_exists?(:obs,
                         %i[concept_id voided obs_datetime person_id value_drug],
                         name: 'idx_obs_dispensation_lookup')
      add_index :obs, %i[concept_id voided obs_datetime person_id value_drug],
                name: 'idx_obs_dispensation_lookup'
    end
  end

  def down
    %w[
      idx_pp_program_voided_patient
      idx_ps_ppid_state_voided_start
      idx_orders_type_voided_start_patient
      idx_orders_concept_voided_patient_start
      idx_obs_adherence_lookup
      idx_obs_art_start_date_lookup
      idx_obs_reason_art_lookup
      idx_enc_type_program_voided_datetime
      idx_enc_patient_type_voided_datetime
      idx_pa_type_voided_person
      idx_obs_dispensation_lookup
    ].each do |idx|
      connection = ActiveRecord::Base.connection
      table = case idx
              when /idx_pp/ then :patient_program
              when /idx_ps/ then :patient_state
              when /idx_orders/ then :orders
              when /idx_obs/ then :obs
              when /idx_enc/ then :encounter
              when /idx_pa/ then :person_attribute
              end
      connection.execute("DROP INDEX #{idx} ON #{table}") if index_exists?(table, [], name: idx)
    rescue StandardError => e
      Rails.logger.warn("Could not drop index #{idx}: #{e.message}")
    end
  end
end
