# frozen_string_literal: true

class IndexPatientIdentifierVoided < ActiveRecord::Migration[5.2]
  def change
    add_index(:patient_identifier, %i[voided identifier_type identifier],
              name: 'index_pi_on_voided_and_identifier_type_and_identifier')
  end
end
