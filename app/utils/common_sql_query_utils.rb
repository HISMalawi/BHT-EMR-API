# frozen_string_literal: true

# This is a module that can be included in any class that needs to use the methods defined here.
module CommonSqlQueryUtils
  def process_occupation(start_date:, end_date:, occupation:, definition: 'moh')
    return if occupation.blank?

    ARTService::Reports::CohortBuilder.new(outcomes_definition: definition).init_temporary_tables(start_date, end_date, occupation)
  end

  def occupation_filter(occupation:, field_name:, table_name: '', include_clause: true)
    clause = 'WHERE' if include_clause
    table_name = "#{table_name}." unless table_name.blank?
    return '' if occupation.blank?
    return '' if occupation == 'All'
    return "#{clause} #{table_name}#{field_name} = '#{occupation}'" if occupation == 'Military'
    return "#{clause} #{table_name}#{field_name} != 'Military'" if occupation == 'Civilian'
  end

  def external_client_query(end_date:)
    end_date = ActiveRecord::Base.connection.quote(end_date)
    <<~SQL
      SELECT obs.person_id FROM obs,
      (SELECT person_id, Max(obs_datetime) AS obs_datetime, concept_id FROM obs
      WHERE concept_id IN (SELECT concept_id FROM concept_name WHERE name = 'Type of patient' AND voided = 0)
      AND DATE(obs_datetime) <= #{end_date}
      AND voided = 0
      GROUP BY person_id) latest_record
      WHERE obs.person_id = latest_record.person_id
      AND obs.concept_id = latest_record.concept_id
      AND obs.obs_datetime = latest_record.obs_datetime
      AND obs.value_coded IN (SELECT concept_id FROM concept_name WHERE name = 'Drug refill' || name = 'External consultation')
      AND obs.voided = 0
    SQL
  end
end
