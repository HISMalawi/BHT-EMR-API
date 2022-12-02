module HtsService
  module Reports
    module Stats
      class HtsDashboard
        def initialize(start_date:, end_date:)
          @start_date = start_date
          @end_date = end_date
        end

        def data
          {
            total_enrolled_into_art: total_enrolled_into_art,
            total_registered: total_registered,
            total_tested_returning: total_tested_returning
          }
        end
1
        def base_query
          Observation.joins("INNER JOIN concept_name cn ON cn.concept_id = obs.concept_id")
                     .joins("INNER JOIN encounter e ON e.encounter_id = obs.encounter_id")
                     .joins("INNER JOIN encounter_type et ON e.encounter_type = et.encounter_type_id")
                     .where("e.program_id = 18 AND e.voided = 0 AND obs.voided = 0" )
        end

        def total_registered
          base_query.where("et.name = 'Testing' AND  cn.name = 'HIV Status'")
                   .where('DATE(obs_datetime) BETWEEN ? AND ?', @start_date, @end_date)
                   .count
        end

        def total_enrolled_into_art
          on_art_concept = 7010
          base_query.where("et.name = 'ART_FOLLOWUP' AND cn.name = 'Antiretroviral therapy referral'")
                   .where("obs.value_coded = #{on_art_concept}")
                   .where("DATE(obs_datetime) BETWEEN '#{@start_date}' AND '#{@end_date}'")
                   .count
        end

        def total_tested_returning
          base_query.where("et.name = 'APPOINTMENT' AND cn.name = 'Appointment date'")
                   .where('DATE(obs.value_datetime) BETWEEN ? AND ? ', @start_date, @end_date)
                   .count
        end
      end
    end
  end
end