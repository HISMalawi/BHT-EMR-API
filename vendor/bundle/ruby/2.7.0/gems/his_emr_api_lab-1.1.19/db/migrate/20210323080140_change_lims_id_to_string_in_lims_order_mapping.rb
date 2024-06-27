# frozen_string_literal: true

class ChangeLimsIdToStringInLimsOrderMapping < ActiveRecord::Migration[5.2]
  def change
    reversible do |direction|
      direction.up do
        change_column :lab_lims_order_mappings, :lims_id, :string, null: false
      end

      direction.down do
        change_column :lab_lims_order_mappings, :lims_id, :integer, null: false
      end
    end
  end
end
