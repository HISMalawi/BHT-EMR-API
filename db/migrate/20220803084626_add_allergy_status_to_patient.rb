class AddAllergyStatusToPatient < ActiveRecord::Migration[5.2]
  def change
    add_column :patient, :allergy_status, :string, limit: 50
  end
end
