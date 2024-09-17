class AddVoidReasonToVisit < ActiveRecord::Migration[7.0]
  def change
    add_column :visit, :void_reason, :string
  end
end
