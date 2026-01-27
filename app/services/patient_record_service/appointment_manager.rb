# app/services/patient_record_service/appointment_manager.rb
# frozen_string_literal: true

module PatientRecordService
  class AppointmentManager < BaseSaver
    def save_appointments(patient_id, record)
      return false unless record[:appointments][:unsaved]&.any?

      encounter_id = create_encounter(patient_id, 7, record)

      save_obs(
        encounter_id: encounter_id,
        observations: record[:appointments][:unsaved],
        location_id: record[:location_id]
      )
      record[:appointments][:unsaved] = []
      true
    end
  end
end