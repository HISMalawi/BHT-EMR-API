# frozen_string_literal: true

class AlterPatientStateTable < ActiveRecord::Migration[5.2]
  def up
    # add uuid column if it doesn't exist
    add_column :patient_state, :uuid, :string unless column_exists?(:patient_state, :uuid)

    # get all patient states with uuid whether voided or not
    PatientState.where(uuid: nil, voided: [0, 1]).each do |patient_state|
      patient_state.uuid = SecureRandom.uuid
      patient_state.save
    end

    # execute alter table and have uuid as not null and unique
    ActiveRecord::Base.connection.execute <<~SQL
      ALTER TABLE patient_state MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
    SQL
  end

  def down
    remove_column :patient_state, :uuid
  end
end
