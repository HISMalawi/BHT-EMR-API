# frozen_string_literal: true

# Follow-up fixes for cohort report index issues identified during live testing.
#
# 1. idx_obs_reason_art_lookup – original column order (concept_id, voided, person_id, obs_datetime)
#    prevents range access on obs_datetime for the ROW_NUMBER() window-function query:
#      WHERE concept_id = ? AND voided = 0 AND obs_datetime < ?
#      ... ROW_NUMBER() OVER (PARTITION BY person_id ORDER BY obs_datetime DESC)
#    The optimizer ignores it and falls back to index_merge(obs_concept, voided_idx).
#    Fix: drop and recreate as (concept_id, voided, obs_datetime, person_id, value_coded)
#    so obs_datetime becomes the range column immediately after the two equality predicates.
#
# 2. obs – ARV dispensation fallback (load_temp_art_start_date_by_enrollment step 3)
#    The optimizer drives from drug → concept_set → obs using answer_concept_drug (single
#    value_drug column). Adding (value_drug, concept_id, voided, obs_datetime, person_id)
#    turns the 8 k-row-per-drug obs scan into a tight equality + range access.
#
class FixCohortReportIndexes < ActiveRecord::Migration[6.1]
  def up
    # -----------------------------------------------------------------------
    # 1. Replace idx_obs_reason_art_lookup with corrected column order
    # -----------------------------------------------------------------------
    if index_exists?(:obs, %i[concept_id voided person_id obs_datetime],
                     name: 'idx_obs_reason_art_lookup')
      remove_index :obs, name: 'idx_obs_reason_art_lookup'
    end

    unless index_exists?(:obs,
                         %i[concept_id voided obs_datetime person_id value_coded],
                         name: 'idx_obs_reason_art_lookup')
      add_index :obs, %i[concept_id voided obs_datetime person_id value_coded],
                name: 'idx_obs_reason_art_lookup'
    end

    # -----------------------------------------------------------------------
    # 2. obs – dispensation lookup driven from drug table
    #    Query: obs JOIN drug ON obs.value_drug = drug.drug_id
    #           WHERE obs.concept_id = 2834 AND obs.voided = 0
    #           AND obs.obs_datetime < date
    #    Pattern: value_drug equality (from join) + concept_id equality + voided + datetime range
    # -----------------------------------------------------------------------
    unless index_exists?(:obs,
                         %i[value_drug concept_id voided obs_datetime person_id],
                         name: 'idx_obs_dispensation_by_drug')
      add_index :obs, %i[value_drug concept_id voided obs_datetime person_id],
                name: 'idx_obs_dispensation_by_drug'
    end
  end

  def down
    # Restore original reason_art index
    if index_exists?(:obs,
                     %i[concept_id voided obs_datetime person_id value_coded],
                     name: 'idx_obs_reason_art_lookup')
      remove_index :obs, name: 'idx_obs_reason_art_lookup'
    end

    unless index_exists?(:obs, %i[concept_id voided person_id obs_datetime],
                         name: 'idx_obs_reason_art_lookup')
      add_index :obs, %i[concept_id voided person_id obs_datetime],
                name: 'idx_obs_reason_art_lookup'
    end

    if index_exists?(:obs, %i[value_drug concept_id voided obs_datetime person_id],
                     name: 'idx_obs_dispensation_by_drug')
      remove_index :obs, name: 'idx_obs_dispensation_by_drug'
    end
  end
end
