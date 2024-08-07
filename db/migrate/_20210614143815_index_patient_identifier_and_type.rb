# frozen_string_literal: true

class IndexPatientIdentifierAndType < ActiveRecord::Migration[5.2]
  def up
    return if index_exists?(:patient_identifier, %i[identifier_type identifier])

    add_index(:patient_identifier, %i[identifier_type identifier])
  end

  def down
    return unless index_exists?(:patient_identifier, %i[identifier_type identifier])

    remove_index(:patient_identifier, %i[identifier_type identifier])
  end
end
