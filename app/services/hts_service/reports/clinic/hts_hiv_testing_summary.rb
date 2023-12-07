# frozen_string_literal: true

module HtsService
  module Reports
    module Clinic
      class HtsHivTestingSummary
        include HtsService::Reports::HtsReportBuilder

        attr_accessor :start_date, :end_date, :report

        LINKAGE_TYPES = %i[linked_within_facility referred_outside_the_facility linked_in_another_facility].freeze
        ACCESS_POINTS = %i[htc vct opd anc outreach].freeze
        AGE_GROUPS = { zero_to_nine: 0..9, ten_to_nineteen: 10..19, twenty_plus: 20..120 }.freeze
        GENDER_GROUPS = %i[male female].freeze
        INDICATORS = %i[tested tested_hiv_positive].freeze

        def initialize(start_date:, end_date:)
          @start_date = Date.parse(start_date).beginning_of_day
          @end_date = Date.parse(end_date).end_of_day
          @report = {}
        end

        def data
          init_report
        end

        def init_report
          sections = {
            test: ->(person) { build_test_report(person) },
            linkage: ->(person) { build_linkage_report(person) },
            referral: ->(person) { build_referral_report(person) }
          }
          report_types = %i[test linkage referral]
          constr_indicators.each { |k, _| @report[k] = [] }
          query.each do |person|
            report_types.each do |type|
              indicator = sections[type].call(person)
              (@report[indicator] ||= []) << person['person_id'] if indicator
            end
          end
          @report
        end

        def constr_indicators
          output = {}
          ACCESS_POINTS.each do |access_point|
            AGE_GROUPS.each do |age_group_name, _age_range|
              GENDER_GROUPS.each do |gender|
                LINKAGE_TYPES.each do |linkage_type|
                  key = "#{access_point}_#{age_group_name}_#{linkage_type}_#{gender}"
                  output[key.to_sym] = []
                end
                INDICATORS.each do |indicator|
                  output_key = "#{access_point}_#{age_group_name}_#{indicator}_#{gender}"
                  output[output_key.to_sym] = []
                end
              end
            end
          end
          output
        end

        def build(person)
          age = Date.today.year - person['birthdate'].year
          gender = person['gender'] == 'M' ? 'male' : 'female'
          access_point = person['location'].downcase.to_sym
          return nil unless ACCESS_POINTS.include?(access_point)

          age_group_name = AGE_GROUPS.select { |_, age_range| age_range.include?(age) }.keys.first
          [gender, age_group_name, access_point]
        end

        def build_test_report(person)
          begin
            gender, age_group_name, access_point = build(person)
          rescue StandardError
            nil
          end
          indicator = person['status'] == 'Positive' ? 'tested_hiv_positive' : 'tested'
          return nil if access_point.nil?

          "#{access_point}_#{age_group_name}_#{indicator}_#{gender}"
        end

        def build_linkage_report(person)
          begin
            gender, age_group_name, access_point = build(person)
          rescue StandardError
            nil
          end
          linkage_type = calc_linkage_type(person['outcome_facility'])
          return nil if linkage_type.nil? || gender.nil?

          "#{access_point}_#{age_group_name}_#{linkage_type}_#{gender}"
        end

        def build_referral_report(person)
          return nil if person['referred_to'].blank?

          begin
            gender, age_group_name, access_point = build(person)
          rescue StandardError
            nil
          end
          return nil if access_point.nil?

          referred = person['referred_to']
          unless referred != Location.find(GlobalProperty.find_by_property('current_health_center_id').property_value.to_i).name
            return nil
          end

          "#{access_point}_#{age_group_name}_referred_outside_the_facility_#{gender}"
        end

        def calc_linkage_type(outcome_facility)
          case outcome_facility
          when Location.find(GlobalProperty.find_by_property('current_health_center_id').property_value.to_i).name
            'linked_within_facility'
          when nil
            nil
          else
            'linked_in_another_facility'
          end
        end

        def query
          ActiveRecord::Base.connection.select_all(his_patients_rev
            .merge(
              Patient.joins(<<-SQL)
            LEFT JOIN obs linked ON linked.voided = 0 AND linked.person_id = person.person_id
            AND linked.concept_id = #{concept('Antiretroviral status or outcome').concept_id}
            LEFT JOIN obs outcome on outcome.voided = 0 AND outcome.person_id = person.person_id
            AND outcome.concept_id = #{concept('ART clinic location').concept_id}
            LEFT JOIN obs hiv_status ON hiv_status.voided = 0 AND hiv_status.person_id = person.person_id
            AND hiv_status.concept_id = #{concept('HIV status').concept_id}
            LEFT JOIN obs location on location.voided = 0 AND location.person_id = person.person_id
            AND location.concept_id = #{concept('Location where test took place').concept_id}
            LEFT JOIN obs referred on referred.voided = 0 AND referred.person_id = person.person_id
            AND referred.concept_id = #{concept('Referral location').concept_id}
              SQL
            ).select('person.person_id, person.gender, person.birthdate, max(outcome.value_text) as outcome_facility, hiv_status.value_coded as status, location.value_text as location, referred.value_text as referred_to')
            .distinct
            .group('person.person_id')
            .to_sql).to_hash
        end
      end
    end
  end
end
