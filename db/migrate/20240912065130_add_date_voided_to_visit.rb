class AddDateVoidedToVisit < ActiveRecord::Migration[7.0]
  def change
    add_column :visit, :date_voided, :datetime
  end
end
