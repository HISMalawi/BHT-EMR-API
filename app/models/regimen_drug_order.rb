# frozen_string_literal: true

class RegimenDrugOrder < VoidableRecord
  self.table_name = :regimen_drug_order
  self.primary_key = :regimen_drug_order_id

  belongs_to :regimen, optional: true
  belongs_to :drug, foreign_key: :drug_inventory_id, optional: true

  def to_s
    s = "#{drug.name}: #{dose} #{units} #{frequency}"
    s << ' (prn)' if prn == 1
    s
  end
end
