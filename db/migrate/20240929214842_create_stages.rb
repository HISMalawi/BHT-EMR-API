class CreateStages < ActiveRecord::Migration[7.0]
  def change
    create_table :stages do |t|
      t.references :visit, null: false, foreign_key: true  
      t.integer :patient_id, null: false 

      t.string :stage
      t.datetime :arrivalTime
      t.boolean :status

      t.timestamps
    end

    # Add the foreign key constraint
    add_foreign_key :stages, :patient, column: :patient_id, primary_key: :patient_id
  end
end
