class CreateStages < ActiveRecord::Migration[7.0]
  def change
    create_table :stages do |t|
      t.string :patientId
      t.string :stage
      t.datetime :arrivalTime
      t.references :visit, null: false, foreign_key: true  
      t.boolean :status

      t.timestamps
    end
  end
end
