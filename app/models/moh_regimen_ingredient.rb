# frozen_string_literal: true

class MohRegimenIngredient < VoidableRecord
  self.table_name = 'moh_regimen_ingredient'
  self.primary_key = 'ingredient_id'

  belongs_to :drug, foreign_key: :drug_inventory_id
  belongs_to :dose, class_name: 'MohRegimenDose', foreign_key: :dose_id
  belongs_to :regimen, class_name: 'MohRegimen', foreign_key: :regimen_id
end
