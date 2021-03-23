class PopulateAlternativeDrugName < ActiveRecord::Migration[5.2]
  def up
    DrugCms.all.each do |cms|
      name = cms.name.split(',')[0]
      AlternativeDrugName.create(
        name: name.strip,
        short_name: cms.short_name.strip,
        drug_inventory_id: cms.drug_inventory_id
      )
    end
  end

  def down
    execute 'DELETE FROM alternative_drug_names'
  end
end
