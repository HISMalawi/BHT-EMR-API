class UpdateDtg50Dose < ActiveRecord::Migration[5.2]
  def up
    drug_id = Drug.find_by_name('Dolutegravir (50mg tablet)').id
    dose_id = MohRegimenDose.find_by(am: 1, pm: 0).id

    execute <<~SQL
      UPDATE moh_regimen_ingredient
      SET dose_id = #{dose_id}
      WHERE drug_inventory_id = #{drug_id}
    SQL
  end

  def down
    drug_id = Drug.find_by_name('Dolutegravir (50mg tablet)').id
    dose_id = MohRegimenDose.find_by(am: 0, pm: 1).id

    execute <<~SQL
      UPDATE moh_regimen_ingredient
      SET dose_id = #{dose_id}
      WHERE drug_inventory_id = #{drug_id}
    SQL
  end
end
