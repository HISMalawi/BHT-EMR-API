class CreateValidationResults < ActiveRecord::Migration[5.2]
  def self.up                                                                   
    create_table :validation_results, :id => false  do |t|                                     
      t.integer :id, :null => false
      t.integer :rule_id                                                        
      t.integer :failures      # number of patients who failed to satisfy rule  
      t.date    :date_checked  # date when this set of results were generated   
                                                                                
      t.timestamps                                                              
    end                            
    execute "ALTER TABLE `validation_results` CHANGE COLUMN `id` `id` INT(11) NOT NULL AUTO_INCREMENT, ADD PRIMARY KEY (`id`);"
  end                                                                           
                                                                                
  def self.down                                                                 
    drop_table :validation_results                                              
  end 
end
