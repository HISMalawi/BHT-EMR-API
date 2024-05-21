# frozen_string_literal: true

# Ait Integration Job
class AitIntergrationJob < ApplicationJob
  queue_as :default
  rescue_from(Exception) do |_exception|
    retry_job wait: 5.minutes, queue: :default
  end

  def perform(**args)
    HtsService::AitIntergration::AitIntergrationService.new(**args).sync
  end
end
