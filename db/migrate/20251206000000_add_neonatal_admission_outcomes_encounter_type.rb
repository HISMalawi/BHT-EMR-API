# frozen_string_literal: true

class AddNeonatalAdmissionOutcomesEncounterType < ActiveRecord::Migration[7.0]
  def up
    execute <<-SQL.squish
      INSERT INTO encounter_type (
        encounter_type_id,
        name,
        description,
        creator,
        date_created,
        uuid,
        retired
      ) VALUES (
        228,
        'NEONATAL ADMISSION OUTCOMES',
        'Neonatal admission outcome and safeguarding concerns encounter',
        1,
        NOW(),
        UUID(),
        0
      )
      ON DUPLICATE KEY UPDATE
        name = VALUES(name),
        description = VALUES(description);
    SQL
  end

  def down
    execute <<-SQL.squish
      DELETE FROM encounter_type
      WHERE encounter_type_id = 228;
    SQL
  end
end
