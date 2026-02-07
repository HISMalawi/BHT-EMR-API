# frozen_string_literal: true

class RenameNeonatalAdmissionOutcomeConcepts < ActiveRecord::Migration[7.0]
  OLD_OUTCOME = 'Admission outcome'
  NEW_OUTCOME = 'Clinical review outcome'

  OLD_OUTCOME_OTHER = 'Admission outcome other'
  NEW_OUTCOME_OTHER = 'Clinical review outcome other'

  def up
    return unless table_exists?(:concept_name)

    execute <<~SQL.squish
      UPDATE concept_name
         SET name = '#{NEW_OUTCOME}'
       WHERE voided = 0
         AND name = '#{OLD_OUTCOME}'
    SQL

    execute <<~SQL.squish
      UPDATE concept_name
         SET name = '#{NEW_OUTCOME_OTHER}'
       WHERE voided = 0
         AND name = '#{OLD_OUTCOME_OTHER}'
    SQL
  end

  def down
    return unless table_exists?(:concept_name)

    execute <<~SQL.squish
      UPDATE concept_name
         SET name = '#{OLD_OUTCOME}'
       WHERE voided = 0
         AND name = '#{NEW_OUTCOME}'
    SQL

    execute <<~SQL.squish
      UPDATE concept_name
         SET name = '#{OLD_OUTCOME_OTHER}'
       WHERE voided = 0
         AND name = '#{NEW_OUTCOME_OTHER}'
    SQL
  end
end

