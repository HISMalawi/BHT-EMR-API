class AddVoidedByToVisit < ActiveRecord::Migration[7.0]
  def change
    add_column :visit, :voided_by, :integer
  end
end
