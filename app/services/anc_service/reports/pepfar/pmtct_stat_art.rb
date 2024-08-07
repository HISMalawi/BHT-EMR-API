# rubocop:disable Metrics/AbcSize, Metrics/BlockLength, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity, Metrics/ClassLength
# frozen_string_literal: true

module AncService
  module Reports
    module Pepfar
      ##
      # HIV-positive pregnant women who received ART to reduce the \
      # risk of mother-to-child-transmission (MTCT) during pregnancy
      class PmtctStatArt
        ANC_AGE_GROUPS = [
          '<10 years',
          '10-14 years',
          '15-19 years',
          '20-24 years',
          '25-29 years',
          '30-34 years',
          '35-39 years',
          '40-44 years',
          '45-49 years',
          '50-54 years',
          '55-59 years',
          '60-64 years',
          '65-69 years',
          '70-74 years',
          '75-79 years',
          '80-84 years',
          '85-89 years',
          '90 plus years',
          'Unknown'
        ].freeze

        def initialize(start_date:, end_date:, **_kwargs)
          @start_date = start_date
          @end_date = end_date + 1.day
        end

        def find_report
          report = init_report_structure
          response = []
          process_clients(pmtct_clients, report).each do |key, value|
            response << { age_group: key, **value }
          end
          response
        end

        private

        def init_report_structure
          ANC_AGE_GROUPS.each_with_object({}) do |age_group, report|
            report[age_group] =
              { known_positive: [], newly_tested_positives: [], new_negatives: [], recent_negatives: [],
                not_done: [], new_on_art: [], already_on_art: [] }
          end
        end

        def pmtct_clients
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT p.person_id                                       AS patient_id,
              anc_age_group(p.birthdate, '#{@end_date}')          AS age_group,
              MIN(prev_test.value_coded)                        AS prev_test,
              MIN(prev_test_result.value_coded)                 AS prev_test_result,
              MIN(current_test_result.value_coded)              as hiv_status,
              MIN(art_status.value_coded)                       AS art_status,
              pepfar_patient_outcome(p.person_id, '#{@end_date}') AS current_outcome,
              date_antiretrovirals_started(p.person_id, '#{@end_date}') outcome_date
            FROM person p
                INNER JOIN (SELECT e.encounter_datetime, e.patient_id
                     FROM encounter e
                              INNER JOIN obs ob ON e.encounter_id = ob.encounter_id
                         AND ob.voided = 0
                         AND ob.concept_id = #{concept('Week of first visit').id}
                         AND e.encounter_type = (SELECT encounter_type_id FROM encounter_type WHERE name = 'CURRENT PREGNANCY' LIMIT 1)
                         AND e.encounter_datetime BETWEEN '#{@start_date}' AND '#{@end_date}'
                     ) first_visit ON first_visit.patient_id = p.person_id
                INNER JOIN encounter visit ON visit.patient_id = p.person_id
                  AND visit.encounter_type = (SELECT encounter_type_id FROM encounter_type where name = 'Lab results' LIMIT 1)
                  AND DATE(visit.encounter_datetime) = DATE(first_visit.encounter_datetime)
                  AND visit.encounter_datetime BETWEEN '#{@start_date}' AND '#{@end_date}'
                  AND visit.voided = 0
                  AND p.voided = 0
                  AND visit.program_id = (SELECT program_id FROM program WHERE name = 'ANC PROGRAM' LIMIT 1)
                LEFT JOIN obs prev_test ON prev_test.encounter_id = visit.encounter_id
                  AND prev_test.voided = 0
                  AND prev_test.concept_id = #{concept('Previous HIV test done').id}
                LEFT JOIN obs prev_test_result ON prev_test_result.encounter_id = visit.encounter_id
                  AND prev_test_result.voided = 0
                  AND prev_test_result.concept_id = #{concept('Previous HIV test results').id}
                LEFT JOIN obs current_test_result ON current_test_result.encounter_id = visit.encounter_id
                  AND current_test_result.voided = 0
                  AND current_test_result.concept_id = #{concept('HIV status').id}
                LEFT JOIN obs art_status ON art_status.encounter_id = visit.encounter_id
                  AND art_status.voided = 0
                  AND art_status.concept_id = #{concept('On ART').id}
            GROUP BY p.person_id
          SQL
        end

        def process_clients(clients, report_structure)
          clients.uniq.each do |client|
            if client['prev_test'] == yes_concept && client['prev_test_result'] == positive_concept \
              || (client['current_outcome'] == 'On antiretrovirals' && client['outcome_date'] < @end_date&.to_date)
              report_structure[client['age_group']][:known_positive] << client['patient_id']
              report_structure[client['age_group']][:already_on_art] << client['patient_id']
              next
            end
            if client['prev_test_result'] != positive_concept && client['hiv_status'] == positive_concept
              report_structure[client['age_group']][:newly_tested_positives] << client['patient_id']
              report_structure[client['age_group']][:new_on_art] << client['patient_id']
              next
            end
            if client['prev_test'] != yes_concept && client['hiv_status'] == negative_concept
              report_structure[client['age_group']][:new_negatives] << client['patient_id']
              next
            end
            if client['prev_test'] == yes_concept && client['prev_test_result'] == negative_concept
              report_structure[client['age_group']][:recent_negatives] << client['patient_id']
              next
            end
            if (client['prev_test'] != yes_concept || client['prev_test'].blank?) && client['hiv_status'].blank?
              report_structure[client['age_group']][:not_done] << client['patient_id']
              next
            end
            if client['art_status'] != yes_concept && client['current_outcome'] == 'On antiretrovirals'
              report_structure[client['age_group']][:new_on_art] << client['patient_id']
              report_structure[client['age_group']][:newly_tested_positives] << client['patient_id']
              next
            end
            if client['art_status'] == yes_concept
              report_structure[client['age_group']][:known_positive] << client['patient_id']
              report_structure[client['age_group']][:already_on_art] << client['patient_id']
            end
          end
          report_structure
        end

        def negative_concept
          @negative_concept ||= concept_name_id('Negative')
        end

        def positive_concept
          @positive_concept ||= concept_name_id('Positive')
        end

        def yes_concept
          @yes_concept ||= concept_name_id('Yes')
        end

        def concept_name_id(name)
          ConceptName.find_by_name(name).concept_id
        end
      end
    end
  end
end

# rubocop:enable Metrics/AbcSize, Metrics/BlockLength, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity, Metrics/ClassLength
