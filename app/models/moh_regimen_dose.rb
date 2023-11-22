# frozen_string_literal: true

class MohRegimenDose < VoidableRecord
  self.table_name = 'moh_regimen_doses'
  self.primary_key = 'dose_id'

  has_many :ingredients, class_name: 'MohRegimenIngredients',
                         foreign_key: :dose_id
end
