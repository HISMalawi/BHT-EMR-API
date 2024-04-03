# frozen_string_literal: true

class EncounterService
  def self.recent_encounter(encounter_type_name:, patient_id:, date: nil,
                            start_date: nil, program_id: nil)
    start_date ||= Date.strptime('1900-01-01')
    date ||= Date.today
    type = EncounterType.find_by(name: encounter_type_name)

    query = Encounter.where(type:, patient_id:)\
                     .where('encounter_datetime BETWEEN ? AND ?',
                            start_date.to_date.strftime('%Y-%m-%d 00:00:00'),
                            date.to_date.strftime('%Y-%m-%d 23:59:59'))
    query = query.where(program_id:) if program_id
    query.order(encounter_datetime: :desc).first
  end

  def create(type:, patient:, program:, encounter_datetime: nil, provider: nil)
    encounter_datetime ||= Time.now
    provider ||= User.current.person

    encounter = find_encounter(type:, patient:, provider:,
                               encounter_datetime:, program:)
    if type.id == EncounterType.find_by(name: 'LAB ORDERS')&.id
      PatientProgramService.new.create(patient:, program: Program.find_by(name: 'Laboratory program'),
                                       date_enrolled: encounter_datetime)
    end
    return encounter if encounter

    Encounter.create(
      type:, patient:, provider:,
      encounter_datetime:, program:,
      location_id: Location.current.id
    )
  end

  def update(encounter, program:, patient: nil, type: nil, encounter_datetime: nil,
             provider: nil)
    updates = {
      patient:, type:, provider:,
      program:, encounter_datetime:
    }
    updates = updates.keep_if { |_, v| !v.nil? }

    encounter.update(updates)
    encounter
  end

  def find_encounter(type:, patient:, encounter_datetime:, provider:, program:)
    Encounter.where(type:, patient:, program:)\
             .where('encounter_datetime BETWEEN ? AND ?',
                    *TimeUtils.day_bounds(encounter_datetime))\
             .order(encounter_datetime: :desc)
             .first
  end

  def void(encounter, reason)
    encounter.void(reason)
  end
end
