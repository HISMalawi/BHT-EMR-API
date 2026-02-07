# frozen_string_literal: true

require "securerandom"

class RenameNeonatalAdmissionOutcomesEncounterType < ActiveRecord::Migration[7.0]
  NEW_NAME = 'NEONATAL CLINICAL REVIEW OUTCOMES'
  OLD_NAME = 'NEONATAL ADMISSION OUTCOMES'

  def up
    return unless table_exists?(:encounter_type)

    execute <<~SQL.squish
      UPDATE encounter_type
         SET name = '#{NEW_NAME}'
       WHERE encounter_type_id = 234
         AND name <> '#{NEW_NAME}'
    SQL

    execute <<~SQL.squish
      UPDATE encounter_type
         SET name = '#{NEW_NAME}'
       WHERE name = '#{OLD_NAME}'
    SQL

    uuid = SecureRandom.uuid

    execute <<~SQL.squish
      INSERT INTO encounter_type (encounter_type_id, name, description, creator, date_created, retired, uuid)
      SELECT 234, '#{NEW_NAME}', 'Neonatal clinical review outcomes', 1, CURRENT_TIMESTAMP, 0, '#{uuid}'
      WHERE NOT EXISTS (SELECT 1 FROM encounter_type WHERE encounter_type_id = 234)
    SQL
  end

  def down
    return unless table_exists?(:encounter_type)

    execute <<~SQL.squish
      UPDATE encounter_type
         SET name = '#{OLD_NAME}'
       WHERE encounter_type_id = 234
         AND name <> '#{OLD_NAME}'
    SQL

    execute <<~SQL.squish
      UPDATE encounter_type
         SET name = '#{OLD_NAME}'
       WHERE name = '#{NEW_NAME}'
    SQL
  end
end

