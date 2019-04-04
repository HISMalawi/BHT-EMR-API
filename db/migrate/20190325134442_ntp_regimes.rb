class NtpRegimes < ActiveRecord::Migration[5.2]
  def change
    create_table :ntp_regimens do |t|
      t.belongs_to :drug, limit: 11
      t.float :am_dose
      t.float :noon_dose, default: 0
      t.float :pm_dose, default: 0
      t.float :min_weight
      t.float :max_weight
      t.integer :creator, default: 0
      t.float :retired_by, default: 0
      t.integer :voided, default: 0
      t.string :void_reason, null: true
      t.timestamps
    end
  end
end
