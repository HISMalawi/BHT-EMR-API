# frozen_string_literal: true

module HtsService
  module Reports
    module Stats
      class HtsDashboard
        def initialize(start_date:, end_date:)
          @start_date = Date.parse(start_date).beginning_of_day
          @end_date = Date.parse(end_date).end_of_day
        end

        def data
          {
            total_enrolled_into_art:,
            total_registered:,
            total_tested_returning:,
            total_positive:
          }
        end

        def base_query
          Observation.joins(concept: :concept_names, encounter: %i[program type])
                     .where(program: { program_id: 18 })
        end

        def total_positive
          base_query.where(
            encounter_type: { name: 'Testing' },
            concept_name: { name: 'HIV Status' },
            obs: { obs_datetime: @start_date..@end_date, value_coded: 703 }
          ).select(:concept_id).count
        end

        def total_registered
          base_query.where(
            encounter_type: { name: 'Testing' },
            concept_name: { name: 'HIV Status' },
            obs: { obs_datetime: @start_date..@end_date }
          ).select(:concept_id).count
        end

        def total_enrolled_into_art
          linked_concept = concept('Linked').concept_id
          base_query.where(
            encounter_type: { name: 'ART_FOLLOWUP' },
            concept_name: { name: 'Antiretroviral status or outcome' },
            obs: { obs_datetime: @start_date..@end_date, value_coded: linked_concept }
          ).select(:concept_id).count
        end

        def total_tested_returning
          base_query.where(
            encounter_type: { name: 'APPOINTMENT' },
            concept_name: { name: 'Appointment date' },
            obs: { value_datetime: @start_date..@end_date }
          ).select(:concept_id).count
        end
      end
    end
  end
end
