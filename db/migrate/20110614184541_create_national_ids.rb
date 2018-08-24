class CreateNationalIds < ActiveRecord::Migration[5.2]
  def self.up
    create_table :national_ids, :id => false do |t|
      t.integer :id, :null => false

      t.timestamps
    end
    execute "ALTER TABLE `national_ids` CHANGE COLUMN `id` `id` INT(11) NOT NULL AUTO_INCREMENT, ADD PRIMARY KEY (`id`);"
  end

  def self.down
    drop_table :national_ids
  end
end
