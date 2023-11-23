# frozen_string_literal: true

class PushDDEFootprintsJob < ApplicationJob
  def perform(program_id:, patient_id:, date:, creator_id:)
    patient = Patient.find(patient_id)
    dde_service(program_id).create_patient_footprint(patient, date&.to_date, creator_id)
  end

  private

  def dde_service(program_id)
    DDEService.new(program: Program.find(program_id))
  end
end
