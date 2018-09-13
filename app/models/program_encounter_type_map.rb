# frozen_string_literal: true

class ProgramEncounterTypeMap < ApplicationRecord
  self.table_name = 'program_encounter_type_map'
  self.primary_key = 'program_encounter_type_map_id'

  belongs_to :program, conditions: { retired: 0 }
  belongs_to :encounter_type, conditions: { retired: 0 }
end
