
 class Api::V1::ImmunizationFollowUpController < ApplicationController
      
    def missed_immunizations
      missed_visits = ImmunizationCacheDatum.where(:name=>"missed_immunizations")

      unless missed_visits.empty?
        render json: missed_visits, status: :ok
      else
        render json: {}, status: :not_found
      end
    end

end