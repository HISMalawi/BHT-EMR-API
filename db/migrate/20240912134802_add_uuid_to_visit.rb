class AddUuidToVisit < ActiveRecord::Migration[7.0]
  def change
    add_column :visit, :uuid, :string
  end
end
