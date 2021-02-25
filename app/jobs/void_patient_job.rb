# frozen_string_literal: true

class VoidPatientJob < ApplicationJob
  def perform(patient_id, reason, user_id)
    User.current = User.find(user_id)
    patient = Patient.find(patient_id)

    patient_service.void_patient(patient, reason, daemonize: false)
  rescue StandardError => e
    logger.error("Failed to void patient ##{patient_id} due to #{e}:")
    raise e
  end

  private

  def patient_service
    PatientService.new
  end
end
