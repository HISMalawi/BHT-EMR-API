# frozen_string_literal: true

module EncounterService
  class << self
    def recent_encounter(encounter_type_name:, patient_id:, date: nil)
      date ||= Time.now
      encounter_type = EncounterType.find_by(name: encounter_type_name)
      Encounter.where(
        'DATE(encounter_datetime) = DATE(?) AND patient_id = ? AND encounter_type = ?',
        date, patient_id, encounter_type.encounter_type_id
      ).order(encounter_datetime: :desc).first
    end
  end
end
