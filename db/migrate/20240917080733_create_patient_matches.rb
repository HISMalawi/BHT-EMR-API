class CreatePatientMatches < ActiveRecord::Migration[7.0]
  def change
    create_table :patient_matches do |t|
      t.integer :patient_id_a, null: false, index: true   # Primary patient ID
      t.integer :patient_id_b, null: false, index: true   # Secondary (duplicate) patient ID
      t.integer :match_percentage                        
      t.boolean :merge_status,null: false, default: false
      
      t.datetime :date_created
      t.boolean :voided, null: false, default: false
      t.integer :voided_by                               
      t.datetime :date_voided                           
      t.string :void_reason                             
      
      t.datetime :date_changed                          
      t.integer :changed_by                             
      t.string :uuid, null: false 

      t.timestamps                                       
    end
  end
end

