class AddIdToDrugCms < ActiveRecord::Migration[5.2]
  def change
    execute 'ALTER TABLE `drug_cms` MODIFY drug_inventory_id INT NOT NULL'
    execute 'ALTER TABLE `drug_cms` DROP PRIMARY KEY'
    add_column :drug_cms, :id, :primary_key
  end
end
