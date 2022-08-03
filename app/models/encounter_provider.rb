class EncounterProvider < VoidableRecord
  belongs_to :encounter
  belongs_to :provider
  belongs_to :encounter_role
end
