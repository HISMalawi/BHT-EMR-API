# frozen_string_literal: true

module HtsService
  module Reports
    module Pepfar
      # HTS_TST_Fac1 report
      class HtsTstFac1
        include HtsService::Reports::HtsReportBuilder
        attr_reader :start_date, :end_date, :report, :numbering

        ACCESS_POINTS = { index: 'Index', opd: 'OPD', emergency: 'Emergency', inpatient: 'Inpatient',
                          malnutrition: 'Malnutrition', pediatric: 'Pediatric', pmtct_anc1: 'ANC First Visit',
                          sns: 'SNS', sti: 'STI', tb: 'TB', vct: 'VCT', vmmc: 'VMMC', other_pitc: 'Other PITC',
                          pmtct_fup_preg: 'PMTCT FUP', pmtct_fup_bf: 'PMTCT FUP' }.freeze

        def initialize(start_date:, end_date:)
          @start_date = start_date.to_date.beginning_of_day
          @end_date = end_date.to_date.end_of_day
          @report = []
          @numbering = 0
        end

        def data
          fetch_data
        end

        private

        def fetch_data
          rows = hts_age_groups.collect { |age_group| construct_row age_group }.flatten
          rows = rows.collect { |row| calc_access_points query, row }
          rows.flatten.uniq
        end

        def calc_age_groups(data, age_group)
          x = data.select { |q| q['age_group'] == age_group.values.first }
          {
            pos: x.select { |q| q['status'] == concept('Positive').concept_id }.map { |q| q['person_id'] },
            neg: x.select { |q| q['status'] == concept('Negative').concept_id }.map { |q| q['person_id'] }
          }
        end

        def calc_access_points(data, row)
          ACCESS_POINTS.each_with_index do |(key, value)|
            x = patients_in_access_point(data, value)

            # seperate pmtct fup preg and pmtct fup bfde
            if key == :pmtct_fup_preg
              x = x.select { |q| q['pregnancy_status'] == concept('Pregnant woman').concept_id }
            elsif key == :pmtct_fup_bf
              x = x.select { |q| q['pregnancy_status'] == concept('Breastfeeding').concept_id }
            end

            row[key.to_s] = calc_age_groups(x.select { |q| q['gender'] == row[:gender].to_s.strip }, row[:age_group])
            row['age_group'] = row[:age_group].values.first
          end
          row
        end

        def construct_row(age_group)
          %i[M F].collect do |gender|
            {
              num_index: @numbering += 1,
              gender:,
              age_group:
            }
          end
        end

        def patients_in_access_point(patients, facility)
          patients.select { |q| /#{q['access_point']}/.match? facility }
        end

        def query
          query = his_patients_rev
                  .joins(<<-SQL)
        INNER JOIN obs facility ON facility.person_id = person.person_id
        AND facility.voided = 0#{'        '}
        AND facility.concept_id = #{concept('Location where test took place').concept_id}
        INNER JOIN obs test_one ON test_one.person_id = person.person_id
        AND test_one.voided = 0
        AND test_one.concept_id = #{concept('Test 1').concept_id}
        LEFT JOIN obs access_type ON access_type.person_id = person.person_id
        AND access_type.voided = 0#{'        '}
        AND access_type.concept_id = #{concept('HTS Access Type').concept_id}
        AND access_type.value_coded = #{concept('Health facility').concept_id}\
        LEFT JOIN obs hiv_status ON hiv_status.person_id = person.person_id
        AND hiv_status.voided = 0#{'        '}
        AND hiv_status.concept_id = #{concept('HIV status').concept_id}
        LEFT JOIN obs pregnancy_status ON pregnancy_status.person_id = person.person_id
        AND pregnancy_status.voided = 0
        AND pregnancy_status.concept_id = #{concept('Pregnancy status').concept_id}
                  SQL
                  .select("disaggregated_age_group(person.birthdate, '#{@end_date.to_date}') as age_group, person.person_id, person.gender, facility.value_text as access_point, hiv_status.value_coded as status, pregnancy_status.value_coded pregnancy_status")
                  .group('person.person_id')
                  .to_sql
          Person.connection.select_all(query)
        end
      end
    end
  end
end
