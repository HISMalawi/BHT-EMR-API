# frozen_string_literal: true

class AitIntergrationJob < ApplicationJob
  queue_as :default

  def perform(patient_id)
    HtsService::AitIntergration::AitIntergrationService.new(patient_id).sync
  end
end
