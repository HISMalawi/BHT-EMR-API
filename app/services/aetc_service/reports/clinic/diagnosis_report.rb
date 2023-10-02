# frozen_string_literal: true

module AetcService
  module Reports
    module Clinic
      # A diagnosis report of the clinic
      class DiagnosisReport
        include ModelUtils
        attr_reader :start_date, :end_date, :age_group

        def initialize(start_date:, end_date:, **kwargs)
          @start_date = start_date.to_date.beginning_of_day.strftime('%Y-%m-%d %H:%M:%S')
          @end_date = end_date.to_date.end_of_day.strftime('%Y-%m-%d %H:%M:%S')
          @age_group = kwargs[:age_group] || 'all'
        end

        def find_report
          flatten_report_data || []
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
          '40 to <50' => [480, 600]
        }.freeze

        def diagnosis
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT e.patient_id, cn.name, pe.birthdate, timestampdiff(month, pe.birthdate, '#{end_date}') age_in_months
            FROM encounter e
            INNER JOIN patient p ON p.patient_id = e.patient_id AND p.voided = 0
            INNER JOIN person pe ON pe.person_id = e.patient_id AND pe.voided = 0
            INNER JOIN encounter_type et ON et.encounter_type_id = e.encounter_type AND et.name = 'OUTPATIENT DIAGNOSIS' AND et.retired = 0
            INNER JOIN obs o ON o.encounter_id = e.encounter_id AND o.voided = 0 AND o.concept_id IN ("#{concept('PRIMARY DIAGNOSIS').concept_id}", "#{concept('SECONDARY DIAGNOSIS').concept_id}")
            INNER JOIN concept_name cn ON cn.concept_id = o.value_coded AND cn.voided = 0
            WHERE e.encounter_datetime >= '#{start_date}' AND e.encounter_datetime <= '#{end_date}' AND e.program_id = #{program('AETC PROGRAM').program_id} AND e.voided = 0
            GROUP BY o.value_coded, e.patient_id #{age_in_months_having_clause}
          SQL
        end

        # now we need to process the diagnosis
        def process_diagnosis
          report_data = {}
          diagnosis.each do |diag|
            report_data[diag['name']] = [] unless report_data.key?(diag['name'])
            report_data[diag['name']].push(diag['patient_id'])
          end
          report_data
        end

        # flatten the report data
        def flatten_report_data
          # turn the report into an array of { diagnosis: 'name', count: [patient_ids] }
          report_data = process_diagnosis
          report_data.map do |diag, values|
            { diagnosis: diag, data: values }
          end
        end

        # create a having clause for age in months
        def age_in_months_having_clause
          return '' if age_group == 'all' || age_group.blank?

          min_age, max_age = AGE_IN_MONTHS_MAP[age_group]
          "HAVING age_in_months >= #{min_age} AND age_in_months < #{max_age}"
        end
      end
    end
  end
end
