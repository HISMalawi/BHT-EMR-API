# frozen_string_literal: true

module HtsService
  module Reports
    module Pepfar
      class HtsRecentFac
        include HtsService::Reports::HtsReportBuilder
        attr_reader :start_date, :end_date, :report, :numbering

        RECENT = 'Recent'
        NEGATIVE = 'Negative'
        LONG_TERM = 'Long-Term'

        ACCESS_POINTS = { index: 'Index', emergency: 'Emergency', inpatient: 'Inpatient',
                          malnutrition: 'Malnutrition', pediatric: 'Pediatric', pmtct_anc1_only: 'ANC First Visit',
                          pmtct_post_anc1: 'PMTCT Post ANC',
                          sns: 'SNS', tb: 'TB', other_pitc: 'Other', vct: 'VCT', vmmc: 'VMMC', opd: 'OPD' }.freeze

        def initialize(start_date:, end_date:)
          @start_date = start_date.to_date.beginning_of_day
          @end_date = end_date.to_date.end_of_day
          @report = []
          @numbering = 0
        end

        def data
          init_report
        end

        private

        def init_report
          data = query
          rows = hts_age_groups.collect { |age_group| construct_row age_group }.flatten
          rows = rows.collect { |row| calc_access_points data, row }
          rows.flatten.uniq.sort_by { |row| row[:gender] }
        end

        def calc_age_groups(data, age_group)
          x = data.select { |q| q['age_group'] == age_group.values.first }
          {
            long_term: x.select { |q| q['recency'] == concept(LONG_TERM).concept_id }.map { |q| q['person_id'] },
            recent: x.select { |q| q['recency'] == concept(RECENT).concept_id }.map { |q| q['person_id'] }
          }
        end

        def calc_access_points(data, row)
          ACCESS_POINTS.each_with_index do |(key, value)|
            x = patients_in_access_point(data, value)
            f = calc_age_groups(x.select { |q| q['gender'] == row[:gender].to_s.strip }, row[:age_group])
            row[key.to_s] = f
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
        INNER JOIN obs access_type on access_type.voided = 0
        AND access_type.person_id = person.person_id
        AND access_type.concept_id = #{concept('HTS Access Type').concept_id}
        AND access_type.value_coded = #{concept('Health Facility').concept_id}
        INNER JOIN obs recency ON recency.voided = 0
        AND recency.person_id = person.person_id
        AND recency.concept_id = #{concept('Recency Test').concept_id}
        INNER JOIN obs location ON location.voided = 0
        AND location.person_id = person.person_id
        AND location.concept_id = #{concept('Location where test took place').concept_id}
                  SQL
                  .select("disaggregated_age_group(person.birthdate, '#{@end_date.to_date}') as age_group, person.person_id, person.gender, person.birthdate, location.value_text as access_point, recency.value_coded as recency")
                  .group('person.person_id')
                  .to_sql
          Person.connection.select_all(query)
        end
      end
    end
  end
end
