# frozen_string_literal: true

class Pharmacy < VoidableRecord
  self.table_name = :pharmacy_obs
  self.primary_key = :pharmacy_module_id

  belongs_to :item, class_name: 'PharmacyBatchItem', foreign_key: :batch_item_id,
                    optional: true
  belongs_to :type, class_name: 'PharmacyEncounterType', foreign_key: :pharmacy_encounter_type
end
