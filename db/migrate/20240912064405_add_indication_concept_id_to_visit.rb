class AddIndicationConceptIdToVisit < ActiveRecord::Migration[7.0]
  def change
    add_column :visit, :indication_concept_id, :integer
  end 
end
