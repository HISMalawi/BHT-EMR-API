# frozen_string_literal: true

# Adds idx_obs_fast_lookup to the obs table to support cohort report queries
# that drive from a patient list and constrain by concept_id, voided, and
# obs_datetime range.
#
# Column order: (person_id, concept_id, voided, obs_datetime)
#   - person_id  – equality from patient-list IN/JOIN predicate
#   - concept_id – equality or IN predicate
#   - voided     – equality (always 0)
#   - obs_datetime – range predicate (>=, <)
#
# Used by FORCE INDEX (idx_obs_fast_lookup) in:
#   - load_tmp_max_adherence
#   - load_temp_obs_last_visit
#   - total_pregnant_women (inline fallback path)
#
class AddIdxObsFastLookup < ActiveRecord::Migration[6.1]
  def up
    unless index_exists?(:obs, %i[person_id concept_id voided obs_datetime],
                         name: 'idx_obs_fast_lookup')
      add_index :obs, %i[person_id concept_id voided obs_datetime],
                name: 'idx_obs_fast_lookup'
    end
  end

  def down
    if index_exists?(:obs, %i[person_id concept_id voided obs_datetime],
                     name: 'idx_obs_fast_lookup')
      remove_index :obs, name: 'idx_obs_fast_lookup'
    end
  end
end
