class CreateLocationTagMaps < ActiveRecord::Migration[5.2]
  def self.up
    create_table :location_tag_maps, :id => false do |t|
      t.integer :id, :null => false

      t.timestamps
    end
    execute "ALTER TABLE `location_tag_maps` CHANGE COLUMN `id` `id` INT(11) NOT NULL AUTO_INCREMENT, ADD PRIMARY KEY (`id`);"
  end

  def self.down
    drop_table :location_tag_maps
  end
end
