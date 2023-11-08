# frozen_string_literal: true

module HtsService
  module Reports
    module Moh
      # HTS Initial tested for hiv
      class HtsConfirmatory
        include HtsService::Reports::HtsReportBuilder
        attr_accessor :start_date, :end_date

        YES_ANSWER = 'Yes'
        NO_ANSWER = 'No'
        TESTING_ENCOUNTER = 'HIV Testing'
        REFERRAL_FOR_RETESTING = 'Referral for Re-Testing'
        RISK_CATEGORY = 'client risk category'
        PARTNER_PRESENT = 'Partner Present'
        PARTNER_HIV_STATUS = 'Partner HIV Status'
        REFERALS_ORDERED = 'Referrals ordered'
        TEST_ONE = 'Test 1'
        TEST_TWO = 'Test 2'
        TEST_THREE = 'Test 3'
        TEST_ONE_REPEAT = 'Immediate Repeat Test 1 Result'
        RECENCY = 'Recency Test'
        DBS_COLLECTED = 'Is DBS Sample Collected'
        DBS_NUMBER = 'DBS Specimen ID'
        HIV_GROUP = 'HIV group'
        ART_REFERAL = 'Antiretroviral therapy referral'

        INDICATORS = [
          { name: 'hiv_status', concept_id: concept('HIV status').concept_id, value: 'value_coded', join: 'INNER' },
          {
            name: %w[test_one test_two test_three test_one_repeat],
            concept_id: [concept(TEST_ONE).concept_id, concept(TEST_TWO).concept_id, concept(TEST_THREE).concept_id,
                         concept(TEST_ONE_REPEAT).concept_id],
            join: 'LEFT'
          },
          { name: 'referal_for_retesting', concept_id: concept(REFERRAL_FOR_RETESTING).concept_id, join: 'LEFT' },
          { name: 'risk_category', concept_id: concept(RISK_CATEGORY).concept_id, join: 'LEFT' },
          { name: 'referrals_ordered', concept_id: concept(REFERALS_ORDERED).concept_id, value: 'value_text',
            join: 'LEFT' },
          { name: 'recency', concept_id: concept(RECENCY).concept_id, join: 'LEFT' },
          { name: 'dbs_collected', concept_id: concept(DBS_COLLECTED).concept_id, join: 'LEFT' },
          { name: 'dbs_number', concept_id: concept(DBS_NUMBER).concept_id, join: 'LEFT' },
          { name: 'hiv_group', concept_id: concept(HIV_GROUP).concept_id, join: 'LEFT' },
          { name: 'art_referal', concept_id: concept(ART_REFERAL).concept_id, value: 'value_text', join: 'LEFT' }

        ].freeze

        def initialize(start_date:, end_date:)
          @start_date = start_date&.to_date&.beginning_of_day
          @end_date = end_date&.to_date&.end_of_day
          @data = {
            'art_referral_outcome_not_applicable' => [],
            'specimen_ids_not_applicable' => [],
            'hiv_test_2_result_invalid_entry' => [],
            'hiv_test_2_result_missing' => [],
            'hiv_test_3_result_invalid_entry' => [],
            'hiv_test_3_result_not_applicable_or_missing' => [],
            'hiv_test_1_repeat_result_invalid_entry' => [],
            'hiv_test_1_repeat_result_not_applicable_or_missing' => [],
            'result_given_to_client_invalid_entry' => [],
            'result_given_to_client_missing' => [],
            'invalid_rtri_result' => [],
            'rtri_result_not_done' => [],
            'rtri_result_invalid_entry' => [],
            'dbs_collected_invalid_entry' => [],
            'dbs_collected_missing_where_rtri_recent' => [],
            'specimen_ids_invalid_entry' => [],
            'specimen_ids_missing_where_dbs_collected' => [],
            'referral_for_retesting_after_confirmatory_invalid_entry' => [],
            'referral_for_retesting_after_confirmatory_missing' => [],
            'referral_for_art_initiation_invalid_entry' => [],
            'referral_for_art_initiation_missing' => [],
            'art_referral_outcome_invalid_entry' => [],
            'art_referral_outcome_missing_where_referred_for_art' => [],
            'art_clinic_registration_indexber_invalid_entry' => [],
            'art_clinic_registration_indexber_missing_among_clients_linked_to_art' => [],
            'linking_with_initial_register_missing_linkid' => []
          }
        end

        def data
          init_report
          fetch_confirmatory_register
          fetch_retest_referral
          fetch_art_referral
          fetch_art_referral_outcome
          fetch_hiv_group
          set_unique
        end

        private

        def init_report
          model = his_patients_rev
          INDICATORS.each do |param|
            model = ObsValueScope.call(model:, **param)
          end
          @query = Person.connection.select_all(
            model
              .select('person.gender, person.person_id, person.birthdate')
              .group('person.person_id')
          ).to_hash
        end

        def filter_hash(key, value)
          return @query.select { |q| q[key[0]] == value && q[key[1]] == value } if key.is_a?(Array)

          @query.select { |q| q[key]&.to_s&.strip == value&.to_s&.strip }
        end

        def set_unique
          @data.each do |key, obj|
            @data[key] = obj&.map { |q| q['person_id'] }&.uniq
          end
        end

        def fetch_confirmatory_register
          @data['total_clients_in_confirmatory_register'] = @query
          @data['hiv_test_2_result_negative'] = filter_hash('test_two', concept('Negative').concept_id)
          @data['hiv_test_2_result_positive'] = filter_hash('test_two', concept('Positive').concept_id)
          @data['hiv_test_3_result_negative'] = filter_hash('test_three', concept('Negative').concept_id)
          @data['hiv_test_3_result_positive'] = filter_hash('test_three', concept('Positive').concept_id)
          @data['hiv_test_1_repeat_result_negative'] = filter_hash('test_one_repeat', concept('Negative').concept_id)
          @data['hiv_test_1_repeat_result_positive'] = filter_hash('test_one_repeat', concept('Positive').concept_id)

          @data['rtri_result_longterm'] = filter_hash('recency', concept('Long-Term').concept_id)
          @data['rtri_result_recent'] = filter_hash('recency', concept('Recent').concept_id)
          @data['rtri_result_not_done'] = filter_hash('recency', concept('Not Done').concept_id)
          @data['rtri_result_negative'] = filter_hash('recency', concept('Negative').concept_id)
          @data['rtri_result_missing_among_hiv_positive_clients'] = []

          @data['dbs_collected_no'] = filter_hash('dbs_collected', concept(NO_ANSWER).concept_id)
          @data['dbs_collected_yes'] = filter_hash('dbs_collected', concept(YES_ANSWER).concept_id)
          @data['specimen_ids_valid_ids_entered'] = filter_hash('dbs_collected', concept(YES_ANSWER).concept_id)
          @data['dbs_collected_not_applicable'] = []

          @data['art_clinic_registration_indexber_valid_entry'] = []
          @data['art_clinic_registration_indexber_not_applicable'] = []
          @data['linking_with_initial_register_valid_linkid'] = []
          @data['linking_with_initial_register_invalid_linkid'] = []
        end

        def fetch_hiv_group
          @data['hiv_group_new_positive'] = filter_hash('hiv_group', concept('New Positive').concept_id)
          @data['hiv_group_new_negative'] = filter_hash('hiv_group', concept('New Negative').concept_id)
          @data['hiv_group_exposed_infant'] = filter_hash('hiv_group', concept('New exposed infant').concept_id)
          @data['hiv_group_negative'] = filter_hash('hiv_group', concept('Negative').concept_id)
          @data['hiv_group_positive_retest'] = filter_hash('hiv_group', concept('Positive Re-Test').concept_id)
          @data['hiv_group_new_inconclusive'] = filter_hash('hiv_group', concept('New Inconclusive').concept_id)
          @data['hiv_group_inconclusive_retest'] = filter_hash('hiv_group', concept('Inconclusive Re-Test').concept_id)
        end

        def fetch_retest_referral
          @data['referral_for_retesting_after_confirmatory_no'] =
            filter_hash('referal_for_retesting', concept('NOT done').concept_id)
          @data['referral_for_retesting_after_confirmatory_yes'] =
            filter_hash('referal_for_retesting', concept('Re-Test').concept_id)
        end

        def fetch_art_referral
          @data['referral_for_art_initiation_no'] = filter_hash('art_referal', 'Yes')
          @data['referral_for_art_initiation_yes'] = filter_hash('art_referal', 'No')
        end

        def fetch_art_referral_outcome
          query = Patient.connection.select_all(
            his_patients_rev
              .joins("INNER JOIN obs o5 ON o5.person_id = encounter.patient_id AND o5.voided = 0 AND o5.concept_id = #{ConceptName.find_by_name('Hiv status').concept_id} AND encounter.encounter_id = o5.encounter_id")
              .joins(<<-SQL)
              LEFT JOIN obs linked ON linked.person_id = person.person_id
              AND linked.voided = 0
              AND linked.concept_id = #{concept('Antiretroviral status or outcome').concept_id}
              SQL
              .select('person.person_id, max(linked.value_coded) as value_coded')
              .group('person.person_id').to_sql
          ).to_hash
          @data['art_referral_outcome_linked'] = query.select { |r| r['value_coded'] == concept('Linked').concept_id }
          @data['art_referral_outcome_refused'] = query.select do |r|
            r['value_coded'] == concept('Refused').concept_id
          end
          @data['art_referral_outcome_died'] = query.select { |r| r['value_coded'] == concept('Died').concept_id }
          @data['art_referral_outcome_unknown'] = query.select do |r|
            r['value_coded'] == concept('Unknown').concept_id
          end
        end
      end
    end
  end
end
