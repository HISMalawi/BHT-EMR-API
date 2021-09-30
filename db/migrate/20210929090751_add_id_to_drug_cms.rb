class AddIdToDrugCms < ActiveRecord::Migration[5.2]
  def up
    execute 'ALTER TABLE `drug_cms` MODIFY drug_inventory_id INT NOT NULL'
    execute 'ALTER TABLE `drug_cms` DROP PRIMARY KEY'
    add_column :drug_cms, :id, :primary_key
  end

  # The changes made above don't really affect anything before this point as
  # the table although existing wasn't being used for anything.
  def down; end
end
