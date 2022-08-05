class EncounterRole < RetirableRecord
  self.table_name = :encounter_role
  self.primary_key = :encounter_role_id
  belongs_to :creator, class_name: 'User', foreign_key: 'creator'
  belongs_to :changed_by, class_name: 'User', foreign_key: 'changed_by'
end
