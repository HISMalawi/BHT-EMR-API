class AddOrderRevisionToLimsOrderMapping < ActiveRecord::Migration[5.2]
  def change
    add_column :lab_lims_order_mappings, :revision, :string
  end
end
