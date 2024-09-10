class AddUuidToVisitType < ActiveRecord::Migration[7.0]
  def change
    add_column :visit_type, :uuid, :string
  end
end
