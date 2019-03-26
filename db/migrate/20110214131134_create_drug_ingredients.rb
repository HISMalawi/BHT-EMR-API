class CreateDrugIngredients < ActiveRecord::Migration[5.2]
  def self.up
    create_table :drug_ingredients, :id => false do |t|
      t.integer :id, :null => false

      t.timestamps
    end
    execute "ALTER TABLE `drug_ingredients` CHANGE COLUMN `id` `id` INT(11) NOT NULL AUTO_INCREMENT, ADD PRIMARY KEY (`id`);"
  end

  def self.down
    drop_table :drug_ingredients
  end
end
