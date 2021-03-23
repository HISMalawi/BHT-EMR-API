class AddCourseToMohRegimenIngredient < ActiveRecord::Migration[5.2]
  def up
    return if column_exists? :moh_regimen_ingredient, :course

    add_column :moh_regimen_ingredient, :course, :string, null: true
  end

  def down
    return unless column_exists? :moh_regimen_ingredient, :course

    remove_column :moh_regimen_ingredient, :course
  end
end
