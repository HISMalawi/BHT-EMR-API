class CreateValidationRules < ActiveRecord::Migration[5.2]
  def self.up                                                                   
    create_table :validation_rules, :id => false do |t|                                       
      t.integer :id, :null => false
      t.string  :expr                                                           
      t.text    :desc                                                           
      t.integer :type_id # 1: cohort report; 2: data quality                    
                                                                                
      t.timestamps                                                              
    end                                                                         
    execute "ALTER TABLE `validation_rules` CHANGE COLUMN `id` `id` INT(11) NOT NULL AUTO_INCREMENT, ADD PRIMARY KEY (`id`);"
  end                                                                           
                                                                                
  def self.down                                                                 
    drop_table :validation_rules                                                
  end
end
