# frozen_string_literal: true
class CreateNeonatalProgramAndEncounters < ActiveRecord::Migration[7.0]
  def up
    neonatal_concept_id = create_concept('Neonatal program', 'N/A')

    execute <<-SQL.squish
      INSERT INTO program (concept_id, creator, date_created, name, uuid)
      VALUES (
        #{neonatal_concept_id},
        1,
        NOW(),
        'NEONATAL PROGRAM',
        UUID()
      )
      ON DUPLICATE KEY UPDATE name = name;
    SQL

    encounter_types = [
      {
        name: 'NEONATAL ENROLLMENT',
        description: 'Neonatal program enrollment encounter'
      },
      {
        name: 'NEONATAL TRIAGE',
        description: 'Neonatal triage and initial assessment'
      }
    ]

    encounter_types.each do |encounter_type|
      execute <<-SQL.squish
        INSERT INTO encounter_type (name, description, creator, date_created, uuid, retired)
        VALUES (
          '#{encounter_type[:name]}',
          '#{encounter_type[:description]}',
          1,
          NOW(),
          UUID(),
          0
        )
        ON DUPLICATE KEY UPDATE description = '#{encounter_type[:description]}';
      SQL
    end

    execute <<-SQL.squish
      INSERT INTO global_property (property, property_value, description, uuid)
      VALUES (
        'neonatal.activities',
        'Enrollment,Vitals,Triage,Assessment,Treatment,Dispensing,Appointment,Outcome',
        'Comma-separated list of neonatal workflow activities',
        UUID()
      )
      ON DUPLICATE KEY UPDATE property_value = property_value;
    SQL

    execute <<-SQL.squish
      INSERT INTO global_property (property, property_value, description, uuid)
      VALUES (
        'neonatal.validate_age',
        'false',
        'Enable/disable age validation for neonatal enrollment (0-28 days)',
        UUID()
      )
      ON DUPLICATE KEY UPDATE property_value = property_value;
    SQL
  end

  def down
    execute "DELETE FROM global_property WHERE property IN ('neonatal.activities', 'neonatal.validate_age')"

    execute <<-SQL.squish
      DELETE FROM encounter_type
      WHERE name IN (
        'NEONATAL ENROLLMENT',
        'NEONATAL TRIAGE'
      )
    SQL

    execute "DELETE FROM program WHERE name = 'NEONATAL PROGRAM'"

    execute "DELETE FROM concept WHERE concept_id IN (SELECT concept_id FROM concept_name WHERE name = 'Neonatal program')"
  end

  private

  def create_concept(name, description)
    execute <<-SQL.squish
      INSERT IGNORE INTO concept_class (name, description, creator, date_created, uuid)
      VALUES ('Program', 'Program', 1, NOW(), UUID())
    SQL

    concept_class_id = ActiveRecord::Base.connection.select_value(
      "SELECT concept_class_id FROM concept_class WHERE name = 'Program' LIMIT 1"
    )

    execute <<-SQL.squish
      INSERT IGNORE INTO concept_datatype (name, description, creator, date_created, uuid)
      VALUES ('N/A', 'Not Applicable', 1, NOW(), UUID())
    SQL

    concept_datatype_id = ActiveRecord::Base.connection.select_value(
      "SELECT concept_datatype_id FROM concept_datatype WHERE name = 'N/A' LIMIT 1"
    )

    existing_concept = ActiveRecord::Base.connection.select_value(
      "SELECT c.concept_id FROM concept c
       INNER JOIN concept_name cn ON c.concept_id = cn.concept_id
       WHERE cn.name = '#{name}' LIMIT 1"
    )

    return existing_concept if existing_concept

    execute <<-SQL.squish
      INSERT INTO concept (retired, datatype_id, class_id, is_set, creator, date_created, uuid)
      VALUES (0, #{concept_datatype_id}, #{concept_class_id}, 0, 1, NOW(), UUID())
    SQL

    concept_id = ActiveRecord::Base.connection.select_value('SELECT LAST_INSERT_ID()')

    execute <<-SQL.squish
      INSERT INTO concept_name (
        concept_id, name, locale, creator, date_created,
        voided, uuid, concept_name_type, locale_preferred
      )
      VALUES (
        #{concept_id}, '#{name}', 'en', 1, NOW(),
        0, UUID(), 'FULLY_SPECIFIED', 1
      )
    SQL

    concept_id
  end
end
