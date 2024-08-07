# frozen_string_literal: true

class AddIndexToDrugOrder < ActiveRecord::Migration[5.2]
  def change
    return if ActiveRecord::Base.connection.index_exists?(:drug_order, %i[drug_inventory_id quantity])

    add_index :drug_order, %i[drug_inventory_id quantity], name: 'inventory_item_and_order_quantity'
  end
end
