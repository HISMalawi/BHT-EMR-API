
 class Api::V1::ImmunizationFollowUpController < ApplicationController
      
    def missed_immunizations
      missed_visits = service.fetch_missed_immunizations(User.current.location_id)

      unless missed_visits.empty?
        render json: missed_visits, status: :ok
      else
        render json: {}, status: :not_found
      end
    end

    private 
    def service
      ImmunizationService::FollowUp.new()
    end

end