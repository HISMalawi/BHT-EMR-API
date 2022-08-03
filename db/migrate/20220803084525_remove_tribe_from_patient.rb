class RemoveTribeFromPatient < ActiveRecord::Migration[5.2]
  def change
    remove_column :patient, :tribe, :integer
  end
end
