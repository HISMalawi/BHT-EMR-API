class EncounterProvider < VoidableRecord
  self.table_name = :encounter_provider
  self.primary_key = :encounter_provider_id

  belongs_to :encounter
  belongs_to :provider
  belongs_to :encounter_role
end
