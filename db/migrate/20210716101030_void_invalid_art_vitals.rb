# frozen_string_literal: true

class VoidInvalidArtVitals < ActiveRecord::Migration[5.2]
  def up
    puts 'Voiding weight and height vitals with 0 and null values; please wait...'
    ActiveRecord::Base.connection.execute("SET SESSION sql_mode = ''")

    ActiveRecord::Base.connection.execute <<~SQL
      UPDATE obs
      SET obs.voided = 1,
          obs.voided_by = 1,
          obs.date_voided = NOW(),
          obs.void_reason = 'Invalid vitals: value is 0 or null'
      WHERE obs.concept_id IN (
          SELECT concept_id FROM concept_name WHERE name IN ('Weight (kg)', 'Height (cm)') AND voided = 0
        )
        AND obs.encounter_id IN (
          SELECT encounter_id FROM encounter
          WHERE encounter_type IN (
              SELECT encounter_type_id FROM encounter_type WHERE name = 'VITALS' AND retired = 0
            )
            AND program_id IN (
              SELECT program_id FROM program WHERE name LIKE 'HIV Program' AND retired = 0
            )
            AND voided = 0
        )
        AND (obs.value_numeric IS NULL OR obs.value_numeric = 0)
        AND (obs.value_text IS NULL OR CAST(obs.value_text AS DECIMAL(1)) = 0)
        AND obs.voided = 0;
    SQL
  end

  def down; end
end
