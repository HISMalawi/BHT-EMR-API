module ImmunizationService
    class ClientAdverseEffect
  
      def initialize()
      end
  
      def add_adverse_effects(encounter:, adverse_effects:)
        start_date = TimeUtils.retro_timestamp(create_params[:start_date].to_date)
        created_observations = []
  
        adverse_effects.each do |concept|
          observation = Observation.create!(
            concept_id: concept.concept_id,
            encounter: encounter,
            person_id: encounter.patient_id,
            obs_datetime: start_date,
            location_id: User.current.location_id
          )
          created_observations << observation
        end
  
        created_observations # Return the array of created observations
      end
  
    end
  end
  