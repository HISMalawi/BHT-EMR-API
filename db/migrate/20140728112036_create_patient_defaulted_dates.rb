class CreatePatientDefaultedDates < ActiveRecord::Migration[5.2]
  def self.up
    create_table :patient_defaulted_dates, :id => false do |t|
      t.integer :id, :null => false
      t.integer :patient_id                              
      t.integer :order_id
      t.integer :drug_id
      t.float   :equivalent_daily_dose
      t.integer :amount_dispensed
      t.integer :quantity_given
      t.date    :start_date
      t.date    :end_date
      t.date    :defaulted_date

      t.date :date_created, :default => Date.today
    end
    execute "ALTER TABLE `patient_defaulted_dates` CHANGE COLUMN `id` `id` INT(11) NOT NULL AUTO_INCREMENT, ADD PRIMARY KEY (`id`);"
  end

  def self.down
    drop_table :patient_defaulted_dates
  end
end
