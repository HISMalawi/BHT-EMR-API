# frozen_string_literal: true

class PharmacyEncounterType < RetirableRecord
  self.table_name = :pharmacy_encounter_type
  self.primary_key = :pharmacy_encounter_type_id
end
