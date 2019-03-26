class CreateSendResultsToCouchdbs < ActiveRecord::Migration[5.2]
  def self.up
    create_table :send_results_to_couchdbs, :id => false do |t|
      t.integer :id, :null => false

      t.timestamps
    end
    execute "ALTER TABLE `send_results_to_couchdbs` CHANGE COLUMN `id` `id` INT(11) NOT NULL AUTO_INCREMENT, ADD PRIMARY KEY (`id`);"
  end

  def self.down
    drop_table :send_results_to_couchdbs
  end
end
