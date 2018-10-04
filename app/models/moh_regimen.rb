class MohRegimen < VoidableRecord
  self.table_name =  'moh_regimens'
  self.primary_key = 'regimen_id'

  has_many :ingredients, class_name: 'MohRegimenIngredients'
end
