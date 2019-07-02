class AlternateDtg50RegimenDose < ActiveRecord::Migration[5.2]
  def up
    # DTG drug inventory id is 982
    dose_id = MohRegimenDose.find_by(am: 1.0, pm: 0.0).dose_id
    regimens = MohRegimenIngredient.where(drug_inventory_id: 982, min_weight: 30)

    regimens.each do |regimen|
      regimen.dose_id = dose_id
      regimen.save
    end
  end

  def down
    dose_id = MohRegimenDose.find_by(am: 0.0, pm: 1.0).dose_id
    regimens = MohRegimenIngredient.where(drug_inventory_id: 982, min_weight: 30)

    regimens.each do |regimen|
      regimen.dose_id = dose_id
      regimen.save
    end
  end
end
