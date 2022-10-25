# frozen_string_literal: true

module HtsService
  module Reports
    module Pepfar
      # HTS Self report
      class HtsRecentCommunity
        attr_accessor :start_date, :end_date

        include ARTService::Reports::Pepfar::Utils

        def initialize(start_date:, end_date:)
          @start_date = start_date
          @end_date = end_date
        end

        def find_report
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
        # map entry point to symbols
        ENTRY_POINTS = {
          'VCT' => :vct_comm,
          'Index' => :index,
          'VMMC' => :other_comm_tp,
          'Other' => :other_comm_tp,
          'SNS' => :sns_comm,
          'Mobile' => :mobile_comm
        }.freeze

        def init_report
          pepfar_age_groups.each_with_object({}) do |age_group, report|
            next if ['Unknown', '<1 year', '1-4 years', '5-9 years', '10-14 years'].include?(age_group)

            report[age_group] = GENDER_TYPES.each_with_object({}) do |gender, gender_sub_report|
              gender_sub_report[gender] = {
                index: { recent: 0, long_term: 0 },
                mobile_comm: { recent: 0, long_term: 0 },
                sns_comm: { recent: 0, long_term: 0 },
                vct_comm: { recent: 0, long_term: 0 },
                other_comm_tp: { recent: 0, long_term: 0 }
              }
            end
          end
        end

        def load_patients_into_report(report, patients)
          patients.each do |patient|
            age_group = patient['age_group']
            next if ['Unknown', '<1 year', '1-4 years', '5-9 years', '10-14 years'].include?(age_group)

            report[age_group][patient['gender']][ENTRY_POINTS[patient['entry_point']]][patient['hiv_status'] == 10_576 ? :recent : :long_term] += 1
          end
        end

        def fetch_clients
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT e.patient_id, disaggregated_age_group(p.birthdate, '#{end_date}') AS age_group, p.gender, location.value_text AS entry_point, recency.value_coded AS recency_value
            FROM encounter e
            INNER JOIN obs o ON o.encounter_id = e.encounter_id AND o.voided = 0 AND o.concept_id = #{ConceptName.find_by_name('HTS Access Type').concept_id} AND o.value_coded = #{ConceptName.find_by_name('Community-based organization').concept_id}
            INNER JOIN obs location ON location.encounter_id = e.encounter_id AND location.voided = 0 AND location.concept_id = #{ConceptName.find_by_name('Location where test took place').concept_id}
            INNER JOIN obs recency ON recency.encounter_id = e.encounter_id AND recency.voided = 0 AND recency.concept_id = #{ConceptName.find_by_name('Recency Test').concept_id} AND recency.value_coded IN (#{ConceptName.find_by_name('Recent').concept_id}, #{ConceptName.find_by_name('Long-Term').concept_id})
            INNER JOIN person p ON p.person_id = e.patient_id AND p.voided = 0
            WHERE e.encounter_type = #{EncounterType.find_by_name('SCREENING').encounter_type_id}
            AND e.voided = 0
            AND e.encounter_datetime BETWEEN '#{start_date}' AND '#{end_date}' + INTERVAL 1 DAY
            AND e.program_id = #{Program.find_by_name('HTC PROGRAM').program_id}
          SQL
        end
      end
    end
  end
end
