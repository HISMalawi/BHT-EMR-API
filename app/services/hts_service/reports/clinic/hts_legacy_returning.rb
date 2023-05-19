# rubocop:disable Metrics/MethodLength, Metrics/ClassLength
# frozen_string_literal: true

module HtsService
  module Reports
    module Clinic
      class HtsLegacyReturning # rubocop:disable Style/Documentation
        include HtsService::Reports::HtsReportBuilder
        attr_reader :start_date, :end_date, :report

        NEW_NEGATIVE = concept('New Negative').concept_id
        NEW_POSITIVE = concept('New Positive').concept_id
        NEW_EXPOSED_INFANT = concept('New exposed infant').concept_id
        NEW_INCONCLUSIVE = concept('New Inconclusive').concept_id
        CONFIRMATORY_POSITIVE = concept('Confirmatory Positive').concept_id
        CONFIRMATORY_INCONCLUSIVE = concept('Confirmatory Inconclusive').concept_id
        HIV_GROUP = concept('HIV group').concept_id
        LAST_TESTED = concept('Previous HIV Test Results').concept_id
        PARTNER_PRESENT = concept('Partner present').concept_id
        PREGNANT_WOMAN = concept('Pregnant woman').concept_id
        NOT_PREGNANT = concept('Not Pregnant / Breastfeeding').concept_id
        BREASTFEEDING = concept('Breastfeeding').concept_id
        TEST_ONE = concept('Test 1').concept_id
        TEST_TWO = concept('Test 2').concept_id
        TEST_THREE = concept('Test 3').concept_id
        PREGNANCY_STATUS = concept('Pregnancy status').concept_id

        INDICATORS = [
          { name: 'test_location', concept_id: TEST_LOCATION, value: 'value_text', join: 'LEFT' },
          { name: 'p_status', concept_id: PREGNANCY_STATUS, join: 'LEFT' },
          { name: 'last_tested', concept_id: LAST_TESTED, join: 'LEFT' },
          {
            name: 'partner_present',
            concept_id: PARTNER_PRESENT,
            value: 'value_text',
            join: 'LEFT'
          },
          {
            name: %w[test_one test_two test_three],
            concept_id: [TEST_ONE, TEST_TWO, TEST_THREE],
            join: 'LEFT'
          },
          { name: 'result_given', concept_id: HIV_GROUP, join: 'LEFT' }
        ].freeze

        def initialize(quarter:, year:)
          set_dates(quarter, year)
          @report = {}
          @returning_clients = ->(data) {
            data.where(
              prev_test: {
                value_coded: concept('Self').concept_id,
              }
            )
          }
        end

        def set_dates(quarter, year)
          @start_date = Date.new(year.to_i, (quarter.gsub('Q', '').to_i * 3) - 2, 1).beginning_of_day
          @end_date = @start_date.end_of_quarter.end_of_day
        end

        def data
          init_report
        end

        private

        def fetch_report_indicators
          model = query

          INDICATORS.each do |param|
            model = ObsValueScope.call(model: model, **param)
          end
          @query_data = connection.select_all(model.group('person.person_id')).to_hash
          access_type_and_age_group
          last_tested
          partner_present
          outcome_summary
          result_given_to_client
        end

        def transform_data(report_dup, month, index)
          report_dup.each_key do |key|
            report[key] ||= {}
            process_report_dup_key(report_dup[key], report[key], index, month)
          end
        end

        def process_report_dup_key(report_dup_key, report_key, index, month)
          report_dup_key.each_key do |k|
            report_key["month_#{index + 1}"] ||= {}
            process_access_types(report_dup_key[k], report_key["month_#{index + 1}"], k, month)
            report_key.delete(k)
          end
        end

        def process_access_types(data, report_month, k, month)
          ['Community', 'Health facility'].each do |access_type|
            filtered = filter_by_access_point(data, access_type, month).map { |q| q['person_id'] }.uniq
            report_month["#{access_type.parameterize.underscore}_#{k}"] = filtered
          end
        end

        def init_report
          fetch_report_indicators
          report_dup = report.deep_dup
          (0..2).each_with_index do |month, index|
            month = start_date.months_ago(month).to_date.month
            transform_data(report_dup, month, index)
          end
          report
        end

        def filter_by_access_point(data, access_type, month)
          data.select do |q|
            q['access_type'] == access_type && q['encounter_datetime'].month == month
          end
        end

        def filter_gender(data)
          {
            "male": data.select { |q| q['gender'] == 'M' },
            "female": data.select { |q| q['gender'] == 'F' }
          }
        end

        def result_given_to_client
          data = @query_data
          array = {
                    new_exp_infant: filter_hash(data, 'result_given', NEW_EXPOSED_INFANT),
                    new_inconclusive: filter_hash(data, 'result_given', NEW_INCONCLUSIVE),
                    confirmat_inc: filter_hash(data, 'result_given', CONFIRMATORY_INCONCLUSIVE),
                    total_confpos: filter_hash(data, 'result_given', CONFIRMATORY_POSITIVE),
                    new_negative: filter_hash(data, 'result_given', NEW_NEGATIVE),
                    non_disag: filter_hash(data, 'result_given', NEW_POSITIVE),
                    tot_newpos: filter_hash(data, 'result_given', NEW_POSITIVE),
                  }.merge!(filter_gender(filter_hash(data, 'result_given', NEW_NEGATIVE)))
          array[:total_chec] = array.values.flatten
          report.merge!({ result_given_to_client: array })
        end

        def outcome_summary
          data = @query_data
          report.merge!({
                          outcome_summary: {
                            total_chec: data,
                            single_neg: filter_hash(data, 'test_one', HIV_NEGATIVE),
                            single_pos: filter_hash(data, 'test_one', HIV_POSITIVE),
                            one_and_two_neg: filter_hash(data, %w[test_one test_two], HIV_NEGATIVE),
                            one_and_two_pos: filter_hash(data, %w[test_one test_two], HIV_POSITIVE),
                            one_and_two_disc: data.select do |q|
                              q['test_one'] == HIV_POSITIVE && q['test_two'] == HIV_NEGATIVE && q['test_three'] == HIV_POSITIVE || q['test_one'] == HIV_POSITIVE && q['test_two'] == HIV_POSITIVE && q['test_three'] == HIV_NEGATIVE
                            end
                          }
                        })
        end

        def partner_present
          data = @query_data
          partner_present = {
                            present: filter_hash(data, 'partner_present', 'Yes'),
                            not_present: filter_hash(data, 'partner_present', 'No'),
                         }
          partner_present[:total_chec] = partner_present.values.flatten
          report.merge!({partner_present: partner_present})
        end

        def last_tested
          data = @query_data
          last_test = {
            never_tested: filter_hash(data, 'last_tested', HIV_NEVER_TESTED),
            last_negative: filter_hash(data, 'last_tested', HIV_NEGATIVE),
            last_positive: filter_hash(data, 'last_tested', HIV_POSITIVE),
            last_exposed_infant: filter_hash(data, 'last_tested', HIV_EXPOSED_INFANT),
            inconclusive: filter_hash(data, 'last_tested', HIV_INVALID_OR_INCONCLUSIVE),
          }
          last_test[:total_chec] = last_test.values.flatten
          report.merge!({last_test: last_test})
        end

        def access_type_and_age_group
          data = @query_data
          access_type_hash = {
            pitc: data.select { |q| ['ANC first visit', 'Inpatient', 'STI', 'PMTCT FUP', 'Peadiatric', 'VMMC', 'Malnutrition', 'TB', 'OPD', 'Other PITC'].include?(q['test_location']) },
            frs: filter_hash(data, 'test_location', 'Index'),
            other: data.select { |q| %w[VCT Mobile Other].include?(q['test_location']) }
          }
          access_type_hash[:total_chec] = access_type_hash.values.flatten

          age_group_hash = {
            twenty_five_plus: data.select { |q| birthdate_to_age(q['birthdate']) > 25 },
            zero_to_eleven_months: data.select { |q| birthdate_to_age(q['birthdate']) < 1 },
            one_to_fourteen_years: data.select { |q| (1..14).include?(birthdate_to_age(q['birthdate'])) },
            fiveteen_to_twenty_four_years: data.select { |q| (15..24).include?(birthdate_to_age(q['birthdate'])) }
          }
          age_group_hash[:total_chec] = age_group_hash.values.flatten

          sex_hash = {
            m: filter_hash(data, 'gender', 'M'),
            fnp: data.select { |q| [NOT_PREGNANT, BREASTFEEDING].include?(q['status']) },
            fp: filter_hash(data, 'status', PREGNANT_WOMAN)
          }
          sex_hash[:total_chec] = sex_hash.values.flatten

          report.merge!({
            access_type: access_type_hash,
            age_group: age_group_hash,
            sex: sex_hash
          })
        end

        def filter_hash(data, key, value)
          return data.select { |q| q[key[0]] == value && q[key[1]] == value } if key.is_a?(Array)

          data.select { |q| q[key] == value }
        end

        def connection
          Person.connection
        end

        def birthdate_to_age(birthdate)
          today = Date.today
          today.year - birthdate.year
        end

        def query
          data = his_patients_rev.joins(<<-SQL)
            INNER JOIN obs location ON location.concept_id = #{HTS_ACCESS_TYPE}
            AND location.voided = 0
            AND location.person_id = person.person_id
            INNER JOIN concept_name access_type_name ON access_type_name.concept_id = location.value_coded
            AND access_type_name.voided = 0
            LEFT JOIN obs prev_test ON prev_test.concept_id = #{concept('Previous HIV test done').concept_id}
            AND prev_test.voided = 0
            AND prev_test.person_id = person.person_id
          SQL
          @returning_clients.call(data).select(<<-SQL)
            access_type_name.name as access_type,
            person.person_id,
            person.gender,
            person.birthdate,
            prev_test.value_coded,
            encounter.encounter_datetime
          SQL
        end
      end
    end
  end
end

# rubocop:enable Metrics/MethodLength, Metrics/ClassLength
