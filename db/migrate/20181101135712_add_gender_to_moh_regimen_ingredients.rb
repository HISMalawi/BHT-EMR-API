class AddGenderToMohRegimenIngredients < ActiveRecord::Migration[5.2]
  def up
    add_column :moh_regimen_ingredient, :gender, :string, default: 'MF'
    execute 'UPDATE moh_regimen_ingredient SET min_age = 0 WHERE min_age IS NULL'
    execute 'UPDATE moh_regimen_ingredient SET max_age = 120 WHERE max_age IS NULL'

    MohRegimenIngredient.where('regimen_id > 11').each do |m_ingredient|
      m_ingredient.gender = 'M'
      m_ingredient.min_age = 0
      m_ingredient.max_age = 120
      m_ingredient.min_weight = 30
      m_ingredient.max_weight = 300
      m_ingredient.save

      f_ingredient = m_ingredient.dup
      f_ingredient.gender = 'F'
      f_ingredient.min_age = 45
      f_ingredient.max_age = 120
      f_ingredient.date_created = Time.now
      f_ingredient.date_updated = Time.now
      f_ingredient.creator = 1
      f_ingredient.save
    end
  end

  def down
    execute 'DELETE FROM moh_regimen_ingredient WHERE gender = \'F\''
    remove_column :moh_regimen_ingredient, :gender
  end
end
