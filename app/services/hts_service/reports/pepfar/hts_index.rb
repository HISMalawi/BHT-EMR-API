# frozen_string_literal: true

module HtsService
  module Reports
    module Pepfar
      # HTS Index report
      class HtsIndex
        attr_accessor :start_date, :end_date

        include ArtService::Reports::Pepfar::Utils

        def initialize(start_date:, end_date:)
          @start_date = start_date
          @end_date = end_date
        end

        def data
          report = init_report
          load_patients_into_report report, fetch_clients
          response = []
          report.each do |key, value|
            response << { age_group: key, gender: 'F', **value['F'] }
            response << { age_group: key, gender: 'M', **value['M'] }
          end
          response
        end

        private

        GENDER_TYPES = %w[F M].freeze

        def init_report
          pepfar_age_groups.each_with_object({}) do |age_group, report|
            next if age_group == 'Unknown'

            report[age_group] = GENDER_TYPES.each_with_object({}) do |gender, gender_sub_report|
              gender_sub_report[gender] = {
                index_clients: [],
                offered_index: [],
                accepted_ait: [],
                contacted_elicited: [],
                facility: { new_positives: [], new_negatives: [], known_positives: [], documented_negatives: [] },
                community: { new_positives: [], new_negatives: [], known_positives: [], documented_negatives: [] }
              }
            end
          end
        end

        def load_patients_into_report(report, patients)
          patients.each do |patient|
            report[patient['age_group']][patient['gender']][:index_clients] << patient['person_id']
            unless patient['consent'].blank?
              report[patient['age_group']][patient['gender']][:offered_index] << patient['person_id']
              report[patient['age_group']][patient['gender']][:accepted_ait] << patient['person_id']
            end
            unless patient['consent'].blank?
              report[patient['age_group']][patient['gender']][:contacted_elicited] << { patient: patient['person_id'],
                                                                                        contacts: patient['contacts'] }
            end
            case patient['hts_access_point']&.to_i
            when 8019 # Facility
              if patient['hiv_status']&.to_i == 703 && [664, 9432].include?(patient['previous_hiv_test_result'])
                report[patient['age_group']][patient['gender']][:facility][:new_positives] << patient['person_id']
              end
              if patient['hiv_status']&.to_i == 664 && patient['previous_hiv_test_result'] == 9432
                report[patient['age_group']][patient['gender']][:facility][:new_negatives] << patient['person_id']
              end
              if patient['hiv_status']&.to_i == 703 && patient['previous_hiv_test_result'] == 703
                report[patient['age_group']][patient['gender']][:facility][:known_positives] << patient['person_id']
              end
              # report[patient['age_group']][patient['gender']][:facility][:documented_negatives] << patient['person_id'] if patient['hiv_status']&.to_i == 664 # Negative
            when 1741 # Community
              if patient['hiv_status']&.to_i == 703 && [664, 9432].include?(patient['previous_hiv_test_result'])
                report[patient['age_group']][patient['gender']][:community][:new_positives] << patient['person_id']
              end
              if patient['hiv_status']&.to_i == 664 && patient['previous_hiv_test_result'] == 9432
                report[patient['age_group']][patient['gender']][:community][:new_negatives] << patient['person_id']
              end
              if patient['hiv_status']&.to_i == 703 && patient['previous_hiv_test_result'] == 703
                report[patient['age_group']][patient['gender']][:community][:known_positives] << patient['person_id']
              end
              # report[patient['age_group']][patient['gender']][:community][:documented_negatives] << patient['person_id'] if patient['hiv_status']&.to_i == 664 # Negative
            end
          end
        end

        def fetch_clients
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT
              p.person_id,
              disaggregated_age_group(p.birthdate, '#{end_date}') AS age_group,
              p.gender,
              o2.value_coded AS hiv_status,
              o3.value_coded AS previous_hiv_test_result,
              o4.value_coded AS hts_access_point,
              contacts.consent,
              contacts.contacts
            FROM person p
            INNER JOIN encounter e ON e.patient_id = p.person_id AND e.encounter_type = #{EncounterType.find_by_name('Testing').encounter_type_id} AND e.voided = 0 AND e.program_id = #{Program.find_by_name('HTC Program').program_id}
            INNER JOIN obs o ON o.person_id = e.patient_id AND o.voided = 0 AND e.encounter_id = o.encounter_id
            INNER JOIN obs o2 ON o2.person_id = e.patient_id AND o2.voided = 0 AND o2.concept_id = #{ConceptName.find_by_name('HIV status').concept_id} AND o2.encounter_id = o.encounter_id
            INNER JOIN obs o3 ON o3.person_id = e.patient_id AND o3.voided = 0 AND o3.concept_id = #{ConceptName.find_by_name('Previous HIV Test Results').concept_id} AND o3.encounter_id = o.encounter_id
            INNER JOIN obs o4 ON o4.person_id = e.patient_id AND o4.voided = 0 AND o4.concept_id = #{ConceptName.find_by_name('HTS Access Type').concept_id} AND o4.encounter_id = o.encounter_id
            INNER JOIN (
              SELECT
                e.patient_id,
                MAX(e.encounter_datetime) AS last_visit
              FROM encounter e
              WHERE e.encounter_type = #{EncounterType.find_by_name('Testing').encounter_type_id} AND e.voided = 0 AND e.program_id = #{Program.find_by_name('HTC Program').program_id} AND e.encounter_datetime BETWEEN '#{start_date}' AND '#{end_date}' + INTERVAL 1 DAY
              GROUP BY e.patient_id
            ) AS lastest_visit ON lastest_visit.patient_id = e.patient_id AND DATE(lastest_visit.last_visit) = DATE(e.encounter_datetime)
            LEFT JOIN (
              SELECT
                e.patient_id,
                1 consent,
                SUM(IF(o.concept_id = #{ConceptName.find_by_name('Relationships of contact').concept_id}, 1, 0)) AS contacts,
                DATE(e.encounter_datetime) AS consent_date
              FROM encounter e
              INNER JOIN obs o2 ON o2.encounter_id = e.encounter_id AND o2.voided = 0 AND o2.concept_id IN (#{ConceptName.find_by_name('Consent Confirmation').concept_id}) AND (o2.value_coded = #{ConceptName.find_by_name('Yes').concept_id} OR o2.value_text = 'Yes')
              LEFT JOIN obs o ON o.encounter_id = e.encounter_id AND o.voided = 0 AND o.concept_id IN (#{ConceptName.find_by_name('Relationships of contact').concept_id})
              WHERE e.encounter_type = #{EncounterType.find_by_name('HTS CONTACT').encounter_type_id}
              AND e.voided = 0
              AND e.program_id = #{Program.find_by_name('HTC Program').program_id}
              AND e.encounter_datetime BETWEEN '#{start_date}' AND '#{end_date}' + INTERVAL 1 DAY
              GROUP BY e.patient_id, DATE(e.encounter_datetime)
            ) AS contacts ON contacts.patient_id = e.patient_id AND contacts.consent_date = DATE(e.encounter_datetime)
            WHERE p.voided = 0 AND DATE(e.encounter_datetime) BETWEEN '#{start_date}' AND '#{end_date}' + INTERVAL 1 DAY
            GROUP BY p.person_id
          SQL
        end
      end
    end
  end
end
