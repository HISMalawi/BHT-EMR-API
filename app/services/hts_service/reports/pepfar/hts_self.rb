include ModelUtils
# frozen_string_literal: true
module HtsService
  module Reports
    module Pepfar
      # HTS Self report
      class HtsSelf
        attr_accessor :start_date, :end_date

        include ARTService::Reports::Pepfar::Utils

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

        def load_patients_into_report(report, patients)
          patients.each do | patient |
            age_group = patient['age_group']
            gender = patient['gender']
            report[age_group][gender][:directly_assisted] << patient['directly_assisted'] if !patient['directly_assisted'].nil?
            report[age_group][gender][:unassisted] << patient['unassisted'] if !patient['unassisted'].nil?
            report[age_group][gender][:self_recipient] << patient['self_recipient'] if !patient['self_recipient'].nil?
            report[age_group][gender][:sex_partner] << patient['sex_partner'] if !patient['sex_partner'].nil?
            report[age_group][gender][:other] << patient['other'] if !patient['other'].nil?
          end
        end

        def init_report
          pepfar_age_groups.each_with_object({}) do |age_group, report|
            next if age_group == 'Unknown'

            report[age_group] = GENDER_TYPES.each_with_object({}) do |gender, gender_sub_report|
              gender_sub_report[gender] = {
                directly_assisted: [],
                unassisted: [],
                self_recipient: [],
                sex_partner: [],
                other: []
              }
            end
          end
        end

        def fetch_clients
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT
              p.person_id,
              p.gender,
              disaggregated_age_group(p.birthdate, '#{@end_date}') as age_group,
              directly_assisted.person_id as directly_assisted,
              unassisted.person_id as unassisted,
              self_recipient.person_id as self_recipient,
              sex_partner.person_id as sex_partner,
              other.person_id as other
            FROM
              person p
            INNER JOIN
              encounter e on e.patient_id = p.person_id
            LEFT JOIN
              obs directly_assisted on directly_assisted.encounter_id = e.encounter_id and
              directly_assisted.concept_id = #{concept('Self-test approach').concept_id} and
              directly_assisted.value_text = "Directly-assisted"
            LEFT JOIN
              obs unassisted on unassisted.encounter_id = e.encounter_id and
              unassisted.concept_id = #{concept('Self-test approach').concept_id} and
              unassisted.value_text = "Un-assisted"
            LEFT JOIN
              obs self_recipient on self_recipient.encounter_id = e.encounter_id and
              self_recipient.concept_id = #{concept('Self-test end user').concept_id} and
              self_recipient.value_coded = #{concept('Self').concept_id}
            LEFT JOIN
              obs sex_partner on sex_partner.encounter_id = e.encounter_id and
              sex_partner.concept_id = #{concept('Self-test end user').concept_id} and
              sex_partner.value_coded = #{concept('Sexual Partner').concept_id}
            LEFT JOIN
              obs other on other.encounter_id = e.encounter_id and
              other.concept_id = #{concept('Self-test end user').concept_id} and
              other.value_coded = #{concept('Other').concept_id}
            WHERE
              e.voided = 0 and
              e.program_id = 18 and
              e.encounter_type = #{encounter_type('ITEMS GIVEN').encounter_type_id} and
              DATE(e.encounter_datetime) BETWEEN "#{@start_date}" AND "#{@end_date}"
            GROUP BY p.person_id
          SQL
        end
      end
    end
  end
end
