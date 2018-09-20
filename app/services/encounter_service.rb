# frozen_string_literal: true

module EncounterService
  class << self
    def recent_encounter(encounter_type_name:, patient_id:, date: nil)
      date ||= Time.now
      encounter_type = EncounterType.find_by(name: encounter_type_name)
      Encounter.where(
        'encounter_datetime = (
          SELECT MAX(encounter_datetime) FROM encounter
          WHERE DATE(encounter_datetime) = DATE(?) AND patient_id = ?
                AND encounter_type = ?
        )', date, patient_id, encounter_type.encounter_type_id
      )[0]
    end
  end
end
