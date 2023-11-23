class FixDtgDose < ActiveRecord::Migration[5.2]
  def up
    dtgs = Drug.where(concept_id: ConceptName.find_by_name('Dolutegravir').concept_id)
    ingredients = MohRegimenIngredient.where(drug: dtgs)
    new_dose = MohRegimenDose.where(am: 1, pm: 0).first

    ingredients.each do |ingredient|
      ingredient.update(dose: new_dose)
    end
  end

  def down
    dtgs = Drug.where(concept_id: ConceptName.find_by_name('Dolutegravir').concept_id)
    ingredients = MohRegimenIngredient.where(drug: dtgs)
    old_dose = MohRegimenDose.where(am: 0, pm: 1).first

    ingredients.each do |ingredient|
      ingredient.update(dose: old_dose)
    end
  end
end
