class ImmunizationOverdueJob < ApplicationJob
    queue_as :default
  
    def perform(location_id)
      missed_visits = followup_service.fetch_missed_immunizations(location_id)


      immunization_cache = ImmunizationCacheDatum.find_or_initialize_by(name: "missed_immunizations")
      immunization_cache.update!(value: missed_visits)
    end
  
    private
  
    def followup_service
      ImmunizationService::FollowUp.new
    end
  end
  