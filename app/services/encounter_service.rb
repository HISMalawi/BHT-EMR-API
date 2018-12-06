# frozen_string_literal: true

class EncounterService
  def self.recent_encounter(type_name:, patient_id:, date: nil, start_date: nil)
    start_date ||= Date.strptime('1900-01-01')
    date ||= Date.today
    type = EncounterType.find_by(name: type_name)
    Encounter.where(
      'DATE(encounter_datetime) <= DATE(?)
        AND DATE(encounter_datetime) >= DATE(?)
        AND patient_id = ? AND type = ?',
      date, start_date, patient_id, type.type_id
    ).order(encounter_datetime: :desc).first
  end

  def create(type:, patient:, encounter_datetime: nil, provider: nil)
    encounter_datetime ||= Time.now
    provider ||= User.current

    encounter = find_encounter(type: type, patient: patient, provider: provider,
                               encounter_datetime: encounter_datetime)

    return encounter if encounter

    Encounter.create(
      type: type, patient: patient, provider: provider,
      encounter_datetime: encounter_datetime
    )
  end

  def update(encounter, patient: nil, type: nil, encounter_datetime: nil,
             provider: nil)
    updates = {
      patient: patient, type: type, provider: provider,
      encounter_datetime: encounter_datetime
    }
    updates = updates.keep_if { |_, v| !v.nil? }

    encounter.update(updates)
    encounter
  end

  def find_encounter(type:, patient:, encounter_datetime:, provider:)
    Encounter.where(type: type, patient: patient, provider: provider)\
             .where('encounter_datetime BETWEEN ? AND ?',
                    *TimeUtils.day_bounds(encounter_datetime.to_date))\
             .order(encounter_datetime: :desc)
             .first
  end

  def void(encounter, reason)
    encounter.void(reason)
  end
end
