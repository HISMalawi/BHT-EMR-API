class AddDefaultToLimsOrderMapping < ActiveRecord::Migration[5.2]
  def up
    change_column :lab_lims_order_mappings, :revision, :string, limit: 256, default: nil, null: true
  end

  def down; end
end
