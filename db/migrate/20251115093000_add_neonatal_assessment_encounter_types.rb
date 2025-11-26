# frozen_string_literal: true

class AddNeonatalAssessmentEncounterTypes < ActiveRecord::Migration[7.0]
  ENCOUNTER_TYPES = [
    {
      id: 224,
      name: 'NEONATAL SYSTEMIC EXAMINATION',
      description: 'Comprehensive neonatal systemic examination encounter'
    },
    {
      id: 225,
      name: 'NEONATAL SIGNS & SYMPTOMS',
      description: 'Neonatal presenting signs and symptoms encounter'
    },
    {
      id: 226,
      name: 'NEONATAL REVIEW OF SYSTEMS',
      description: 'Structured neonatal review of systems encounter'
    }
  ].freeze

  def up
    ENCOUNTER_TYPES.each do |encounter_type|
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
          #{encounter_type[:id]},
          '#{encounter_type[:name]}',
          '#{encounter_type[:description]}',
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
  end

  def down
    execute <<-SQL.squish
      DELETE FROM encounter_type
      WHERE encounter_type_id IN (#{ENCOUNTER_TYPES.map { |t| t[:id] }.join(',')})
    SQL
  end
end
