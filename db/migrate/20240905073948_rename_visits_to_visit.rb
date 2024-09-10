class RenameVisitsToVisit < ActiveRecord::Migration[7.0]
  def change
    rename_table :visits, :visit
  end
end
