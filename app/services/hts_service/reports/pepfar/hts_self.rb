# frozen_string_literal: true

include ModelUtils
# frozen_string_literal: true
module HtsService
  module Reports
    module Pepfar
      # HTS Self report
      class HtsSelf
        attr_accessor :start_date, :end_date, :report

        include ArtService::Reports::Pepfar::Utils
        include HtsService::Reports::HtsReportBuilder

        APPROACH = {
          directly_assisted: concept('Directly-Assisted').concept_id,
          unassisted: concept('Un-assisted').concept_id
        }.freeze

        END_USER = {
          self_recipient: concept('Self').concept_id,
          sex_partner: concept('Sexual partner').concept_id,
          caretaker_for_child: concept('Caretaker for child').concept_id,
          other: concept('Other').concept_id
        }.freeze

        def initialize(start_date:, end_date:)
          @start_date = start_date.to_date.beginning_of_day
          @end_date = end_date.to_date.end_of_day
          @report = []
        end

        def data
          init_report query
          report
        end

        private

        def init_report(query)
          female_concept = concept('Female').concept_id
          male_concept = concept('Male').concept_id
          pepfar_age_groups.each do |age_group|
            %i[M F].each do |gender|
              row = {}
              APPROACH.each do |(key, value)|
                q = filter_approach(query, value, age_group, gender == :F ? female_concept : male_concept).map do |r|
                  r['person_id']
                end
                row[key.to_s] = q
              end
              END_USER.each do |(key, value)|
                q = filter_end_user(query, value, age_group, gender == :F ? female_concept : male_concept).map do |r|
                  r['person_id']
                end
                row[key.to_s] = q
              end
              row[:gender] = gender
              row[:age_group] = age_group
              report << row
            end
          end
        end

        def filter_approach(query, kit_approach, group, user_gender)
          query.select do |row|
            age_group, _, _, approach, gender = row.values
            age_group == group && gender == user_gender && approach == kit_approach
          end
        end

        def filter_end_user(query, end_user, group, user_gender)
          query.select do |row|
            age_group, _, user, _, gender = row.values
            age_group == group && gender == user_gender && user == end_user
          end
        end

        def query
          Person.connection.select_all(
            self_test_clients.joins(<<~SQL)
              INNER JOIN obs user ON user.person_id = obs.person_id
              AND user.voided = 0
              AND user.concept_id = #{concept('Self-test end user').concept_id}
              INNER JOIN obs approach ON approach.person_id = obs.person_id
              AND approach.voided = 0
              AND approach.concept_id = #{concept('Self-test approach').concept_id}
              INNER JOIN obs gender ON gender.person_id = obs.person_id
              AND gender.voided = 0
              AND gender.concept_id = #{concept('Gender of contact').concept_id}
              INNER JOIN obs age_group ON age_group.person_id = obs.person_id
              AND age_group.voided = 0
              AND age_group.concept_id = #{concept('Age of contact').concept_id}
              AND age_group.value_datetime is not null
              AND obs.obs_group_id is not null
            SQL
            .select(
              "disaggregated_age_group(age_group.value_datetime, '#{@end_date.to_date}') as age_group,
              person.person_id,
              user.value_coded as user,
              approach.value_coded as approach,
              gender.value_coded as gender"
            )
            .group('gender.value_coded, age_group.value_coded, user.value_coded, gender.value_coded')
            .to_sql
          )
        end
      end
    end
  end
end
