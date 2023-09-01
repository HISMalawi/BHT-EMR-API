class AITIntergrationJob < ApplicationJob
    queue_as :default
    rescue_from(Exception) do |_exception|
        retry_job wait: 5.minutes, queue: :default
    end

    def perform(patient_id)
        HTSService::AITIntergration::AITIntergrationService.new(patient_id).sync
    end
end