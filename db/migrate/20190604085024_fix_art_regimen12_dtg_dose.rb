class FixArtRegimen12DtgDose < ActiveRecord::Migration[5.2]
  def up
    ingredient = MohRegimenIngredient.find_by(drug_inventory_id: 982, regimen_id: 11)
    ingredient.dose_id = MohRegimenDose.find_by(am: 1.0, pm: 0.0).dose_id
    ingredient.save
  end

  def down
    ingredient = MohRegimenIngredient.find_by(drug_inventory_id: 982, regimen_id: 11)
    ingredient.dose_id = MohRegimenDose.find_by(am: 1.0, pm: 1.0).dose_id
    ingredient.save
  end
end
