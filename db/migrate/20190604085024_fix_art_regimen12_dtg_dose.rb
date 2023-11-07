# frozen_string_literal: true

class FixArtRegimen12DTGDose < ActiveRecord::Migration[5.2]
  def up
    dose = MohRegimenDose.find_by(am: 1.0, pm: 0.0)&.dose_id
    ingredient = MohRegimenIngredient.find_by(drug_inventory_id: 982, regimen_id: 11)
    ingredient.dose_id = dose if ingredient.present? && dose.present?
    ingredient.save if ingredient.present?
  end

  def down
    ingredient = MohRegimenIngredient.find_by(drug_inventory_id: 982, regimen_id: 11)
    ingredient.dose_id = MohRegimenDose.find_by(am: 1.0, pm: 1.0).dose_id
    ingredient.save
  end
end
