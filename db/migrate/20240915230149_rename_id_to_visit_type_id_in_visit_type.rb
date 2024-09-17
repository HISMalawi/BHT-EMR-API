class RenameIdToVisitTypeIdInVisitType < ActiveRecord::Migration[7.0]
  def change
    rename_column :visit_type, :id, :visit_type_id   
  end
end
