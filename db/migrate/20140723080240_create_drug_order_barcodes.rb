class CreateDrugOrderBarcodes < ActiveRecord::Migration[5.2]
  def self.up
    create_table :drug_order_barcodes, :id => false  do |t|
      t.integer :drug_order_barcode_id, :null => false
      t.integer :drug_id
      t.integer :tabs
      t.timestamps
    end
    execute "ALTER TABLE `drug_order_barcodes` CHANGE COLUMN `drug_order_barcode_id` `drug_order_barcode_id` INT(11) NOT NULL AUTO_INCREMENT, ADD PRIMARY KEY (`drug_order_barcode_id`);"
  end

  def self.down
    drop_table :drug_order_barcodes
  end
end
