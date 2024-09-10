class AddVisitIdToVisit < ActiveRecord::Migration[7.0]
  def change
    add_column :visit, :visit_id, :integer
  end
end
