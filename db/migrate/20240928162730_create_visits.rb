class CreateVisits < ActiveRecord::Migration[7.0]
  def change
    create_table :visits do |t|
      t.string :patientId
      t.datetime :startDate
      t.datetime :closedDateTime
      t.string :programId

      t.timestamps
    end
  end
end
