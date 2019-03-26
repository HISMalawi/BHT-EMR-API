class EncounterType < RetirableRecord
  self.table_name = :encounter_type
  self.primary_key = :encounter_type_id

  has_many :encounters
end
