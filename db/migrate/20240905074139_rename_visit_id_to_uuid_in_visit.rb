class RenameVisitIdToUuidInVisit < ActiveRecord::Migration[7.0]
  def change
    rename_column :visit, :visit_id, :uuid
  end
end
