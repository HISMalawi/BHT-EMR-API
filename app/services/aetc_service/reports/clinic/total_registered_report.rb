# frozen_string_literal: true

module AetcService
  module Reports
    module Clinic
      # This class is responsible for building the total registered report
      class TotalRegisteredReport
        include ModelUtils

        def initialize(start_date:, end_date:, **kwargs)
          @start_date = start_date.to_date.beginning_of_day.strftime('%Y-%m-%d %H:%M:%S')
          @end_date = end_date.to_date.end_of_day.strftime('%Y-%m-%d %H:%M:%S')
          @age_group = JSON.parse(kwargs[:age_group]) || ['all']
        end

        def fetch_report
          total_registered
        end

        private

        AGE_IN_MONTHS_MAP = {
          '< 6 months' => [0, 6],
          '6 months to < 1 yr' => [6, 12],
          '1 to < 5' => [12, 60],
          '5 to 14' => [60, 168],
          '> 14 to < 20' => [168, 240],
          '20 to 30' => [240, 360],
          '>30 to <40' => [360, 480],
          '40 to <50' => [480, 600],
          'ALL' => [0, 10_000]
        }.freeze

        def total_registered
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT e.patient_id, pn.given_name, pn.family_name, pe.birthdate, COALESCE(LEFT(pe.gender, 1), 'Unknown') gender, pa.city_village address, pa.county_district ta, MIN(e.encounter_datetime) registration_date, timestampdiff(month, pe.birthdate, '#{@end_date}') age_in_months
            FROM encounter e
            INNER JOIN encounter_type et ON et.encounter_type_id = e.encounter_type AND et.name IN ('TREATMENT','OUTPATIENT DIAGNOSIS') AND et.retired = 0
            INNER JOIN patient p ON p.patient_id = e.patient_id AND p.voided = 0
            INNER JOIN person pe ON pe.person_id = e.patient_id AND pe.voided = 0
            INNER JOIN person_name pn ON pn.person_id = e.patient_id AND pn.voided = 0
            INNER JOIN person_address pa ON pa.person_id = e.patient_id AND pa.voided = 0
            WHERE e.encounter_datetime >= '#{@start_date}' AND e.encounter_datetime <= '#{@end_date}' AND e.program_id = #{program('AETC PROGRAM').program_id} AND e.voided = 0
            GROUP BY e.patient_id #{age_in_months_having_clause}
          SQL
        end

        # create a having clause for age in months
        def age_in_months_having_clause
          return '' if @age_group.include?('all') || @age_group.blank?

          having_clause = ''
          @age_group.each_with_index do |age, index|
            min_age, max_age = AGE_IN_MONTHS_MAP[age]
            having_clause += "(age_in_months >= #{min_age} AND age_in_months < #{max_age})" if index.zero?
            having_clause += " OR (age_in_months >= #{min_age} AND age_in_months < #{max_age})" if index.positive?
          end
          "HAVING #{having_clause}"
        end
      end
    end
  end
end
