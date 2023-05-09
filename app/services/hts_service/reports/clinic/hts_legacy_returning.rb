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
        PARTENER_PRESENT = concept('Partner present').concept_id
        PREGNANT_WOMAN = concept('Pregnant woman').concept_id
        NOT_PREGNANT = concept('Not Pregnant / Breastfeeding').concept_id
        BREASTFEEDING = concept('Breastfeeding').concept_id
        TEST_ONE = concept('Test 1').concept_id
        TEST_TWO = concept('Test 2').concept_id
        TEST_THREE = concept('Test 3').concept_id
        PREGNANCY_STATUS = concept('Pregnancy status').concept_id

        def initialize(start_date:, end_date:)
          @start_date = start_date.to_date.beginning_of_day
          @end_date = end_date.to_date.end_of_day
          @report = {}
          @returning_clients = ->(data) {
            data.where(
              prev_test: {
                value_coded: concept('Self').concept_id,
              }
            )
          }
        end

        def data
          init_report
        end

        private

        def init_report
          access_type_and_age_group
          last_tested
          partner_present
          outcome_summary
          result_given_to_client
          r = report.deep_dup
          (start_date.month..end_date.month).each_with_index do |month, index|
            r.each_key do |key|
              report[key] ||= {}
              r[key].each_key do |k|
                data = r[key][k]
                report[key]["month_#{index + 1}"] ||= {}
                report[key]["month_#{index + 1}"]["community_#{k}"] = data.select { |q| q['access_type'] == 'Community' && q['encounter_datetime'].month == month }.map { |q| q['person_id'] }
                report[key]["month_#{index + 1}"]["health_facility_#{k}"] = data.select { |q| q['access_type'] == 'Health facility' && q['encounter_datetime'].month == month}.map { |q| q['person_id'] }
                report[key].delete(k)
              end
            end
          end
          report
        end

        def filter_gender(key, data)
          report.merge!({ result_given_to_client: {
                          "#{key}_male": data.select { |q| q['gender'] == 'M' },
                          "#{key}_female": data.select { |q| q['gender'] == 'F' }
                      }})
        end

        def result_given_to_client
          data = connection.select_all(ObsValueScope.call(model: query, name: 'result_given', concept_id: HIV_GROUP)).to_hash
          filter_gender('new_negative', filter_hash(data, 'result_given', NEW_NEGATIVE))
          filter_gender('new_positive', filter_hash(data, 'result_given', NEW_POSITIVE))
          filter_gender('confirmatory_positive', filter_hash(data, 'result_given', CONFIRMATORY_POSITIVE))
          report.merge!({
                          result_given_to_client: {
                            new_exposed_infant: filter_hash(data, 'result_given', NEW_EXPOSED_INFANT),
                            new_inconclusive: filter_hash(data, 'result_given', NEW_INCONCLUSIVE),
                            confirmatory_inconclusive: filter_hash(data, 'result_given', CONFIRMATORY_INCONCLUSIVE)
                          }
                        })
        end

        def outcome_summary
          data = connection.select_all(
            ObsValueScope.call(
              model: query,
              name: %w[test_one test_two test_three],
              concept_id: [TEST_ONE, TEST_TWO, TEST_THREE],
              join: 'LEFT'
            ).group('person.person_id')
          ).to_hash
          report.merge!({
                          outcome_summary: {
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
          data = connection.select_all(
            ObsValueScope.call(
              model: query,
              name: 'partner_present',
              concept_id: PARTENER_PRESENT,
              value: 'value_text'
            )
          ).to_hash
          report.merge!({
                          partner_present: {
                            present: filter_hash(data, 'partner_present', 'Yes'),
                            not_present: filter_hash(data, 'partner_present', 'No')
                         }
                        })
        end

        def last_tested
          data = connection.select_all(
            ObsValueScope.call(
              model: query,
              name: 'last_tested',
              concept_id: LAST_TESTED
            )
          ).to_hash
          report.merge!({
                          last_test:{
                            never_tested: filter_hash(data, 'last_tested', HIV_NEVER_TESTED),
                            negative: filter_hash(data, 'last_tested', HIV_NEGATIVE),
                            positive: filter_hash(data, 'last_tested', HIV_POSITIVE),
                            exposed_infant: filter_hash(data, 'last_tested', HIV_EXPOSED_INFANT),
                            inconclusive: filter_hash(data, 'last_tested', HIV_INVALID_OR_INCONCLUSIVE)
                          }
                        })
        end

        def access_type_and_age_group
          query_one = ObsValueScope.call(model: query, name: 'test_location', concept_id: TEST_LOCATION, value: 'value_text')
          query_two = ObsValueScope.call(model: query_one, name: 'p_status', concept_id: PREGNANCY_STATUS, join: 'LEFT')
          data = connection.select_all(query_two.group('person.person_id')).to_hash

          report.merge!({
                          access_type: {
                            pitc: data.select { |q|
                                  ['ANC first visit', 'Inpatient', 'STI', 'PMTCT FUP', 'Peadiatric',
                                   'VMMC', 'Malnutrition', 'TB', 'OPD', 'Other PITC'].include?(q['test_location']) },
                            frs: filter_hash(data, 'test_location', 'Index'),
                            other: data.select { |q| %w[VCT Mobile Other].include?(q['test_location']) },
                          },
                          age_group: {
                            twenty_five_plus: data.select { |q| birthdate_to_age(q['birthdate']) > 25 },
                            zero_to_eleven_months: data.select { |q| birthdate_to_age(q['birthdate']) < 1 },
                            one_to_fourteen_years: data.select { |q| (1..14).include?(birthdate_to_age(q['birthdate'])) },
                            fiveteen_to_twenty_four_years: data.select { |q| (15..24).include?(birthdate_to_age(q['birthdate'])) },
                          },
                          sex: {
                            male: filter_hash(data, 'gender', 'M'),
                            fnp: data.select { |q| [NOT_PREGNANT, BREASTFEEDING].include?(q['status']) },
                            fp: filter_hash(data, 'status', PREGNANT_WOMAN)
                          }
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
          data = his_patients_rev
                 .joins(<<-SQL)
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
