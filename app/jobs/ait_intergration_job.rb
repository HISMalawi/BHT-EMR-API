class AITIntergrationJob < ApplicationJob
    queue_as :default

    def perform(patient_id)
        HTSService::AITIntergration::AITIntergrationService.new(patient_id - 1).sync
    end
end