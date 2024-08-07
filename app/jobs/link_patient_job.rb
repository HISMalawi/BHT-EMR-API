# frozen_string_literal: true

class LinkPatientJob < ApplicationJob
  queue_as :default

  def perform(patient, date)
    ActiveRecord::Base.transaction do
      logger.debug("Starting Patient link to HTS program job for patient #{patient.patient_id}")
      HtsService::PatientStateEngine.new(patient, date).link_patient
    end
  end
end
