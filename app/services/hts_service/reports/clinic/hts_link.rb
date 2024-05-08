# frozen_string_literal: true

module HtsService
  module Reports
    module Clinic
      class HtsLink
        include HtsService::Reports::HtsReportBuilder
        attr_reader :start_date, :end_date, :report, :numbering

        INDICATORS = %i[same_facility other_facilities].freeze
        LINKED_DAYS = %i[same_day two_to_seven_days eight_to_twenty_eight_days twenty_eight_days_plus].freeze
        GENDER = %i[female male].freeze

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
          rows = rows.collect { |row| build_report data, row }
          rows.sort_by { |row| row[:gender] }
        end

        def build_report(data, row)
          # raise row[:gender].inspect
          gender_filter = data.select { |a| a['gender'] == row[:gender].to_s }
          age_group_filter = gender_filter.select { |q| q['age_group'] == row[:age_group].to_s }
          same_facility = age_group_filter.select do |q|
            q['facility'] == Location.find(GlobalProperty.find_by_property('current_health_center_id').property_value.to_i).name
          end
          other_facilities = age_group_filter.reject do |q|
            q['facility'] == Location.find(GlobalProperty.find_by_property('current_health_center_id').property_value.to_i).name
          end
          LINKED_DAYS.each do |linked_day|
            row['same_facility'][linked_day.to_s] = same_facility.select do |q|
                                                      calc_linked_days(q) == linked_day.to_sym
                                                    end.map { |q| q['person_id'] }
            row['other_facilities'][linked_day.to_s] = other_facilities.select do |q|
                                                         calc_linked_days(q) == linked_day.to_sym
                                                       end.map { |q| q['person_id'] }
          end
          row
        end

        def calc_linked_days(row)
          diff = (row['linked_date'].to_date - row['date_tested'].to_date).to_i
          return :same_day if diff.zero?
          return :two_to_seven_days if diff >= 2 && diff <= 7
          return :eight_to_twenty_eight_days if diff >= 8 && diff <= 28

          :twenty_eight_days_plus if diff > 28
        end

        def construct_row(age_group)
          %i[M F].collect do |gender|
            arr = {
              num: @numbering += 1,
              gender:,
              age_group: age_group.values.first
            }
            INDICATORS.each do |indicator|
              arr[indicator.to_s] = {}
              LINKED_DAYS.each do |linked_day|
                arr[indicator.to_s][linked_day.to_s] = []
              end
            end
            arr
          end
        end

        def query
          Person.connection.select_all(
            his_patients_rev
              .joins(<<-SQL)
        LEFT JOIN obs linked ON linked.person_id = person.person_id
        AND linked.voided = 0
        AND linked.concept_id = #{concept('Antiretroviral status or outcome').concept_id} AND linked.value_coded = #{concept('Linked').concept_id}
        LEFT JOIN obs facility ON facility.person_id = person.person_id
        AND facility.voided = 0
        AND facility.concept_id = #{concept('ART clinic location').concept_id}
              SQL
            .where.not(facility: { value_text: nil })
              .select("disaggregated_age_group(person.birthdate, '#{@end_date.to_date}') as age_group, linked.obs_datetime AS linked_date, facility.value_text as facility, person.person_id, person.gender, encounter.encounter_datetime as date_tested")
              .group('person.person_id')
              .to_sql
          )
        end
      end
    end
  end
end
