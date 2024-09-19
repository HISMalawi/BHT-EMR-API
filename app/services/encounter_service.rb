# frozen_string_literal: true

class EncounterService
  def self.recent_encounter(encounter_type_name:, patient_id:, date: nil,
                            start_date: nil, program_id: nil)
    start_date ||= Date.strptime('1900-01-01')
    date ||= Date.today
    type = EncounterType.find_by(name: encounter_type_name)

    query = Encounter.where(encounter_type:, patient_id:)\
                     .where('encounter_datetime BETWEEN ? AND ?',
                            start_date.to_date.strftime('%Y-%m-%d 00:00:00'),
                            date.to_date.strftime('%Y-%m-%d 23:59:59'))
    query = query.where(program_id:) if program_id
    query.order(encounter_datetime: :desc).first
  end

  def create(encounter_type:, patient:, program:, visit:, encounter_datetime: nil, provider: nil)
    encounter_datetime ||= Time.now
    provider ||= User.current.person
    
    # TODO To be refactored in future
    unless program.program_id.to_i == Program.find_by_name('IMMUNIZATION PROGRAM').program_id.to_i
      encounter = find_encounter(encounter_type:, patient:, provider:,
                                encounter_datetime:, program:)
      if encounter_type.id == EncounterType.find_by(name: 'LAB ORDERS')&.id
        PatientProgramService.new.create(patient:, program: Program.find_by(name: 'Laboratory program'),
                                        date_enrolled: encounter_datetime)
      end
      return encounter if encounter
    end

    Encounter.create(
      encounter_type:, patient:, provider:,
      encounter_datetime:, program:, visit:,
      location_id: User.current.location_id
    )
  end

  def update(encounter_type:, program:, patient: nil, type: nil, encounter_datetime: nil,
             provider: nil)
    updates = {
      patient:, encounter_type:, provider:,
      program:, encounter_datetime:
    }
    updates = updates.keep_if { |_, v| !v.nil? }

    encounter.update(updates)
    encounter
  end

  def find_encounter(encounter_type:, patient:, encounter_datetime:, provider:, program:)
    Encounter.where(encounter_type:, patient:, program:)\
             .where('encounter_datetime BETWEEN ? AND ?',
                    *TimeUtils.day_bounds(encounter_datetime))\
             .order(encounter_datetime: :desc)
             .first
  end

  def void(encounter, reason)
    encounter.void(reason)
  end
end
