# frozen_string_literal: true

module HtsService
  module Reports
    module Pepfar
      # HTS TST report
      class HtsTstCommunity
        attr_accessor :start_date, :end_date

        include ArtService::Reports::Pepfar::Utils

        POSITIVE = concept('Refer client to HIV clinic').concept_id
        NEGATIVE = concept('Negative').concept_id

        def initialize(start_date:, end_date:)
          @start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
          @end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')
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
        # map entry point to symbols
        ENTRY_POINTS = {
          'VCT' => :vct_comm,
          'Index' => :index_comm,
          'VMMC' => :vmmc_comm,
          'Other' => :other_comm_tp,
          'SNS' => :sns_comm,
          'Mobile' => :mobile_comm
        }.freeze

        def init_report
          pepfar_age_groups.each_with_object({}) do |age_group, report|
            next if ['Unknown', '<1 year', '1-4 years', '5-9 years', '10-14 years'].include?(age_group)

            report[age_group] = GENDER_TYPES.each_with_object({}) do |gender, gender_sub_report|
              gender_sub_report[gender] = {
                index_comm: { pos: [], neg: [] },
                mobile_comm: { pos: [], neg: [] },
                sns_comm: { pos: [], neg: [] },
                vct_comm: { pos: [], neg: [] },
                vmmc_comm: { pos: [], neg: [] },
                other_comm_tp: { pos: [], neg: [] }
              }
            end
          end
        end

        def load_patients_into_report(report, patients)
          patients.each do |patient|
            age_group = patient['age_group']
            next if ['Unknown', '<1 year', '1-4 years', '5-9 years', '10-14 years'].include?(age_group)
            next unless [POSITIVE, NEGATIVE].include?(patient['hiv_status'])

            report[age_group][patient['gender']][ENTRY_POINTS[patient['entry_point']]][patient['hiv_status'] == POSITIVE ? :pos : :neg] << patient['patient_id']
          end
        end

        def fetch_clients
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT e.patient_id, disaggregated_age_group(p.birthdate, '#{end_date.to_date}') AS age_group, p.gender, location.value_text AS entry_point, status.value_coded AS hiv_status
            FROM encounter e
            INNER JOIN obs o ON o.encounter_id = e.encounter_id AND o.voided = 0 AND o.concept_id = #{concept('HTS Access Type').concept_id} AND o.value_coded = #{concept('Community').concept_id}
            INNER JOIN obs location ON location.encounter_id = e.encounter_id AND location.voided = 0 AND location.concept_id = #{concept('Location where test took place').concept_id}
            INNER JOIN obs status ON status.encounter_id = e.encounter_id AND status.voided = 0 AND status.concept_id = #{concept('HIV status').concept_id}
            INNER JOIN person p ON p.person_id = e.patient_id AND p.voided = 0
            WHERE e.encounter_type = #{EncounterType.find_by_name('Testing').encounter_type_id}
            AND e.voided = 0
            AND e.encounter_datetime BETWEEN '#{start_date}' AND '#{end_date}'
            AND e.program_id = #{Program.find_by_name('HTC PROGRAM').program_id}
          SQL
        end
      end
    end
  end
end
