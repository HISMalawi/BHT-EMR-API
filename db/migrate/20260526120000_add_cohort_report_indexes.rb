# frozen_string_literal: true

# Adds composite indexes to obs and orders to speed up the ART cohort report,
# and removes duplicate single-column indexes that cause unnecessary write overhead.
#
# Key queries benefiting from these indexes:
#   - update_patient_current_medication  (obs per-patient + concept + date range)
#   - latest_art_adherence               (obs full-cohort concept scan)
#   - update_patient_side_effects        (obs full-cohort concept scan)
#   - load_max_drug_orders               (orders per-patient + voided + date range)
#   - load_temp_order_details            (orders per-patient + voided + date range)
class AddCohortReportIndexes < ActiveRecord::Migration[6.1]
  def up
    # ------------------------------------------------------------------
    # obs: composite index for per-patient lookups
    # Serves: update_patient_current_medication (all 3 JOIN conditions after
    # DATE() -> range rewrite), latest_art_adherence (adherent/not_adherent)
    # Access path: person_id= -> concept_id= -> voided= -> obs_datetime range
    # ------------------------------------------------------------------
    unless index_exists?(:obs, %i[person_id concept_id voided obs_datetime],
                         name: 'idx_obs_person_concept_voided_date')
      add_index :obs, %i[person_id concept_id voided obs_datetime],
                name: 'idx_obs_person_concept_voided_date'
    end

    # ------------------------------------------------------------------
    # obs: composite index for full-cohort concept scans grouped by person
    # Serves: load_tmp_max_adherence, load_patients_with/without_side_effects
    # Access path: concept_id= -> voided= -> obs_datetime range, covering person_id
    # ------------------------------------------------------------------
    unless index_exists?(:obs, %i[concept_id voided obs_datetime person_id],
                         name: 'idx_obs_concept_voided_date_person')
      add_index :obs, %i[concept_id voided obs_datetime person_id],
                name: 'idx_obs_concept_voided_date_person'
    end

    # ------------------------------------------------------------------
    # orders: composite index for per-patient date-range lookups
    # Serves: load_max_drug_orders, load_patient_current_medication orders JOIN,
    #         load_temp_order_details
    # Access path: patient_id= -> voided= -> start_date range
    # ------------------------------------------------------------------
    unless index_exists?(:orders, %i[patient_id voided start_date],
                         name: 'idx_orders_patient_voided_date')
      add_index :orders, %i[patient_id voided start_date],
                name: 'idx_orders_patient_voided_date'
    end

    # ------------------------------------------------------------------
    # obs: remove 3 duplicate value_datetime indexes (write overhead only)
    # value_datetime (the original) is kept
    # ------------------------------------------------------------------
    remove_index :obs, name: 'value_datetime_2' if index_name_exists?(:obs, 'value_datetime_2')
    remove_index :obs, name: 'value_datetime_3' if index_name_exists?(:obs, 'value_datetime_3')
    remove_index :obs, name: 'value_datetime_4' if index_name_exists?(:obs, 'value_datetime_4')

    # ------------------------------------------------------------------
    # orders: remove 3 duplicate accession_number indexes (write overhead only)
    # accession_number (the original) is kept
    # ------------------------------------------------------------------
    remove_index :orders, name: 'accession_number_2' if index_name_exists?(:orders, 'accession_number_2')
    remove_index :orders, name: 'accession_number_3' if index_name_exists?(:orders, 'accession_number_3')
    remove_index :orders, name: 'accession_number_4' if index_name_exists?(:orders, 'accession_number_4')
  end

  def down
    remove_index :obs, name: 'idx_obs_person_concept_voided_date' if index_name_exists?(:obs, 'idx_obs_person_concept_voided_date')
    remove_index :obs, name: 'idx_obs_concept_voided_date_person' if index_name_exists?(:obs, 'idx_obs_concept_voided_date_person')
    remove_index :orders, name: 'idx_orders_patient_voided_date' if index_name_exists?(:orders, 'idx_orders_patient_voided_date')

    # Restore duplicate indexes on rollback (schema must match exactly)
    add_index :obs, :value_datetime, name: 'value_datetime_2' unless index_name_exists?(:obs, 'value_datetime_2')
    add_index :obs, :value_datetime, name: 'value_datetime_3' unless index_name_exists?(:obs, 'value_datetime_3')
    add_index :obs, :value_datetime, name: 'value_datetime_4' unless index_name_exists?(:obs, 'value_datetime_4')
    add_index :orders, :accession_number, name: 'accession_number_2' unless index_name_exists?(:orders, 'accession_number_2')
    add_index :orders, :accession_number, name: 'accession_number_3' unless index_name_exists?(:orders, 'accession_number_3')
    add_index :orders, :accession_number, name: 'accession_number_4' unless index_name_exists?(:orders, 'accession_number_4')
  end

  private

  # index_exists? in Rails 7 / Ruby 3.2 requires a column_name positional argument —
  # passing name: as a keyword to the two-argument form breaks. This helper
  # checks purely by index name via connection.indexes instead.
  def index_name_exists?(table_name, index_name)
    connection.indexes(table_name).any? { |i| i.name == index_name.to_s }
  end
end
