# frozen_string_literal: true

module HtsService
  module Reports
    module Moh
      # HTS Initial tested for hepb
      class HtsInitialTestedForHepb
        include HtsService::Reports::HtsReportBuilder
        attr_accessor :start_date, :end_date

        YES_ANSWER = concept("Yes").concept_id
        NO_ANSWER = concept("No").concept_id
        TESTING_ENCOUNTER = encounter_type("HIV Testing").encounter_type_id
        HEP_B_TEST_RESULT = concept("Hepatitis B Test Result").concept_id
        SYPHILIS_TEST_RESULT = concept("Syphilis Test Result").concept_id
        PREGNANCY_STATUS = concept("Pregnancy status").concept_id
        CIRCUMCISION_STATUS = concept("Circumcision status").concept_id
        MALE_CONDOMS = concept("Male Condoms").concept_id
        FEMALE_CONDOMS = concept("Female Condoms").concept_id
        FRS = concept("FRS").concept_id
        REFERRAL_FOR_RETESTING = concept("Referral for Re-Testing").concept_id
        TIME_OF_HIV_TEST = concept("Time of HIV test").concept_id
        TIME_SINCE_LAST_MEDICATION = concept("Time since last taken medication").concept_id
        PREVIOUS_HIV_TEST = concept("Previous HIV Test Results").concept_id
        PREVIOUS_HIV_TEST_DONE = concept("Previous HIV Test done").concept_id
        RISK_CATEGORY = concept("client risk category").concept_id
        PARTNER_PRESENT = concept("Partner Present").concept_id
        PARTNER_HIV_STATUS = concept("Partner HIV Status").concept_id
        TAKEN_ARVS_BEFORE = concept("Taken ARV before").concept_id
        TAKEN_PREP_BEFORE = concept("Taken PrEP before").concept_id
        TAKEN_PEP_BEFORE = concept("Taken PEP before").concept_id
        REFERALS_ORDERED = concept("Referrals ordered").concept_id
        TEST_ONE = concept("Test 1").concept_id
        TEST_TWO = concept("Test 2").concept_id
        TEST_THREE = concept("Test 3").concept_id

        PREGNANT_WOMAN = concept("Pregnant woman").concept_id
        NOT_PREGNANT = concept("Not Pregnant / Breastfeeding").concept_id
        BREASTFEEDING = concept("Breastfeeding").concept_id
        INDICATORS = [
          { name: "hiv_status", concept_id: HIV_STATUS_OBS, value: "value_coded", join: "LEFT" },
          { name: "access_type", concept_id: HTS_ACCESS_TYPE, value: "value_coded", join: "LEFT" },
          { name: "test_location", concept_id: TEST_LOCATION, value: "value_text", join: "LEFT" },
          { name: "hep_b_test_result", concept_id: HEP_B_TEST_RESULT, value: "value_coded", join: "INNER" },
          { name: "syphilis_test_result", concept_id: SYPHILIS_TEST_RESULT, value: "value_coded", join: "LEFT" },
          {
            name: %w[test_one test_two test_three],
            concept_id: [TEST_ONE, TEST_TWO, TEST_THREE],
            join: "LEFT",
          },
          { name: "pregnancy_status", concept_id: PREGNANCY_STATUS, value: "value_coded", join: "LEFT" },
          { name: "circumcision_status", concept_id: CIRCUMCISION_STATUS, value: "value_coded", join: "LEFT" },
          { name: "male_condoms", concept_id: MALE_CONDOMS, join: "LEFT", value: 'value_numeric' },
          { name: "female_condoms", concept_id: FEMALE_CONDOMS, join: "LEFT", value: 'value_numeric' },
          { name: "frs", concept_id: FRS, join: "LEFT", value: 'value_numeric' },
          { name: "referal_for_retesting", concept_id: REFERRAL_FOR_RETESTING, join: "LEFT" },
          { name: "time_of_hiv_test", concept_id: TIME_OF_HIV_TEST, value: "value_datetime", join: "LEFT" },
          { name: "time_since_last_medication", concept_id: TIME_SINCE_LAST_MEDICATION, join: "LEFT" },
          { name: "previous_hiv_test", concept_id: PREVIOUS_HIV_TEST, join: "LEFT" },
          { name: "previous_hiv_test_done", concept_id: PREVIOUS_HIV_TEST_DONE, join: "LEFT" },
          { name: "risk_category", concept_id: RISK_CATEGORY, join: "LEFT" },
          { name: "partner_present", concept_id: PARTNER_PRESENT, value: "value_text", join: "LEFT" },
          { name: "partner_hiv_status", concept_id: PARTNER_HIV_STATUS, join: "LEFT" },
          { name: "taken_arvs_before", concept_id: TAKEN_ARVS_BEFORE, join: "LEFT" },
          { name: "taken_prep_before", concept_id: TAKEN_PREP_BEFORE, join: "LEFT" },
          { name: "taken_pep_before", concept_id: TAKEN_PEP_BEFORE, join: "LEFT" },
          { name: "referrals_ordered", concept_id: REFERALS_ORDERED, value: "value_text", join: "LEFT" },
        ]

        def initialize(start_date:, end_date:)
          @start_date = start_date&.to_date&.beginning_of_day
          @end_date = end_date&.to_date&.end_of_day
          @data = {
            "missing_link_id_not_in_conf_register" => [], "linking_with_hiv_confirmatory_register_missing_linkid_not_in_conf_register" => [],
            "hiv_test_1_result_missing" => [], "linking_with_hiv_confirmatory_register_total_clients_hiv_test_1_negative" => [],
            "hepatitis_b_test_result_not_done" => [], "linking_with_hiv_confirmatory_register_invalid_linkid_in_conf_register" => [],
            "hepatitis_b_test_result_missing" => [], "linking_with_hiv_confirmatory_register_total_clients_hiv_test_1_not_done" => [],
            "syphilis_test_result_not_done" => [],
            "hiv_test_1_result_not_done" => [],
            "risk_category_missing" => [],
            "age_group_years_missing" => [],
            "access_point_type_invalid_entry" => [],
            "access_point_type_missing" => [],
            "sex_or_pregnancy_invalid_entry" => [],
            "sex_or_pregnancy_missing" => [],
            "last_hiv_test_invalid_self_test" => [],
            "last_hiv_test_invalid_entry" => [],
            "last_hiv_test_missing" => [],
            "time_since_last_hiv_test_invalid_entry" => [],
            "time_since_last_hiv_test_not_applicable_or_missing" => [],
            "ever_taken_arvs_invalid_entry" => [],
            "ever_taken_arvs_missing" => [],
            "time_since_last_taken_arvs_invalid_entry" => [],
            "time_since_last_taken_arvs_not_applicable_or_missing" => [],
            "risk_category_invalid_entry" => [],
            "hiv_test_1_result_invalid_entry" => [],
            "hepatitis_b_test_result_invalid_entry" => [],
            "syphilis_test_result_invalid_entry" => [],
            "syphilis_test_result_missing" => [],
            "partner_present_invalid_entry" => [],
            "partner_present_missing" => [],
            "partner_hiv_status_invalid_entry" => [],
            "partner_hiv_status_missing" => [],
            "referral_for_hiv_retesting_invalid_entry" => [],
            "referral_for_hiv_retesting_missing" => [],
            "referral_invalid_entry" => [],
            "referral_missing" => [],
            "frs_given_family_referral_slips_sum" => [],
            "frs_given_invalid_entry" => [],
            "male_condoms_given_male_condoms_sum" => [],
            "male_condoms_given_invalid_entry" => [],
            "female_condoms_given_invalid_entry" => [],
            "not_applicable_not_linked" => [],
            "invalid_link_id_in_conf_register" => [],
          }
        end

        def data
          init_report
          fetch_hepatitis_b_clients
          fetch_hiv_tests
          fetch_partner_status
          fetch_referral_retests
          linked_clients
          fetch_risk_category
          fetch_referrals
          fetch_ever_taken_drugs_before
          fetch_items_given
          set_unique
        end

        private

        def init_report
          model = his_patients_rev
          INDICATORS.each do |param|
            model = ObsValueScope.call(model: model, **param)
          end
          @query = Person.connection.select_all(
            model
              .select("person.gender, person.person_id, person.birthdate, previous_hiv_test_done.obs_datetime")
              .group("person.person_id")
          ).to_hash
        end

        def set_unique
          @data.each do |key, obj|
            if %w[frs_given_family_referral_slips_sum male_condoms_given_male_condoms_sum female_condoms_given_female_condoms_sum].include?(key)
              @data[key] = obj
              next
            end
            @data[key] = obj&.map { |q| q["person_id"] }.uniq
          end
        end

        def filter_hash(key, value)
          return @query.select { |q| q[key[0]] == value && q[key[1]] == value } if key.is_a?(Array)

          @query.select { |q| q[key]&.to_s&.strip == value&.to_s&.strip }
        end

        def get_diff(obs_time, time_since)
          diff = (obs_time&.to_date - time_since&.to_date).to_i rescue 10001
          diff
        end

        def birthdate_to_age(birthdate)
          today = Date.today
          today.year - birthdate.year
        end

        def fetch_hepatitis_b_clients
          @data["total_clients_tested_for_hepatitis_b"] = @query
          @data["access_point_type_total_clients_tested_at_the_facility"] = filter_hash("access_type", concept("Health facility").concept_id)
          @data["access_point_type_total_clients_tested_in_the_community"] = filter_hash("access_type", concept("Community").concept_id)
          @data["access_point_type_facility_vct"] = filter_hash("access_type", concept("Health facility").concept_id).select { |q| q["test_location"] == "VCT" }
          @data["access_point_type_facility_anc_first_visit"] = filter_hash("access_type", concept("Health facility").concept_id).select { |q| q["test_location"] == "ANC First visit" }
          @data["access_point_type_facility_inpatient"] = filter_hash("access_type", concept("Health facility").concept_id).select { |q| q["test_location"] == "Inpatient" }
          @data["access_point_type_facility_sti"] = filter_hash("access_type", concept("Health facility").concept_id).select { |q| q["test_location"] == "STI" }
          @data["access_point_type_facility_pmtctfup"] = filter_hash("access_type", concept("Health facility").concept_id).select { |q| q["test_location"] == "PMTCT FUP" }
          @data["access_point_type_facility_index"] = filter_hash("access_type", concept("Health facility").concept_id).select { |q| q["test_location"] == "Index" }
          @data["access_point_type_facility_paediatric"] = filter_hash("access_type", concept("Health facility").concept_id).select { |q| q["test_location"] == "Paediatric" }
          @data["access_point_type_facility_malnutrition"] = filter_hash("access_type", concept("Health facility").concept_id).select { |q| q["test_location"] == "Malnutrition" }
          @data["access_point_type_facility_vmmc"] = filter_hash("access_type", concept("Health facility").concept_id).select { |q| q["test_location"] == "VMMC" }
          @data["access_point_type_facility_tb"] = filter_hash("access_type", concept("Health facility").concept_id).select { |q| q["test_location"] == "TB" }
          @data["access_point_type_facility_opd"] = filter_hash("access_type", concept("Health facility").concept_id).select { |q| q["test_location"] == "OPD" }
          @data["access_point_type_facility_other_pitc"] = filter_hash("access_type", concept("Health facility").concept_id).select { |q| q["test_location"] == "Other PITC" }
          @data["access_point_type_facility_sns"] = filter_hash("access_type", concept("Health facility").concept_id).select { |q| q["test_location"] == "SNS" }
          @data["access_point_type_community_vmmc"] = filter_hash("access_type", concept("Community").concept_id).select { |q| q["test_location"] == "VMMC" }
          @data["access_point_type_community_index"] = filter_hash("access_type", concept("Community").concept_id).select { |q| q["test_location"] == "Index" }
          @data["access_point_type_community_mobile"] = filter_hash("access_type", concept("Community").concept_id).select { |q| q["test_location"] == "Mobile" }
          @data["access_point_type_community_vct"] = filter_hash("access_type", concept("Community").concept_id).select { |q| q["test_location"] == "VCT" }
          @data["access_point_type_community_other"] = filter_hash("access_type", concept("Community").concept_id).select { |q| q["test_location"] == "Other" }
          @data["access_point_type_community_sns"] = filter_hash("access_type", concept("Community").concept_id).select { |q| q["test_location"] == "SNS" }

          @data["sex_or_pregnancy_total_males"] = filter_hash("gender", "M")
          @data["sex_or_pregnancy_male_circumcised"] = filter_hash("circumcision_status", YES_ANSWER)
          @data["sex_or_pregnancy_male_noncircumcised"] = filter_hash("circumcision_status", NO_ANSWER)

          @data["age_group_years_a_under_1"] = @query.select { |q| birthdate_to_age(q["birthdate"]) < 1 }
          @data["age_group_years_b_114"] = @query.select { |q| (1..14).include?(birthdate_to_age(q["birthdate"])) }
          @data["age_group_years_c_1524"] = @query.select { |q| (15..24).include?(birthdate_to_age(q["birthdate"])) }
          @data["age_group_years_d_25plus"] = (@query.select { |q| birthdate_to_age(q["birthdate"]) >= 25 })

          @data["sex_or_pregnancy_total_females"] = filter_hash("gender", "F")
          @data["sex_or_pregnancy_female_pregnant"] = filter_hash("pregnancy_status", PREGNANT_WOMAN)
          @data["sex_or_pregnancy_female_nonpregnant"] = filter_hash("pregnancy_status", NOT_PREGNANT)
          @data["sex_or_pregnancy_female_breastfeeding"] = filter_hash("pregnancy_status", BREASTFEEDING)

          @data["hiv_test_1_result_negative"] = filter_hash("test_one", concept("Negative").concept_id)
          @data["total_clients_hiv_test_1_negative"] = filter_hash("test_one", concept("Negative").concept_id)
          @data["hiv_test_1_result_positive"] = filter_hash("test_one", concept("Positive").concept_id)
          @data["linking_with_hiv_confirmatory_register_total_clients_hiv_test_1_positive"] = filter_hash("test_one", concept("Positive").concept_id)

          @data["hepatitis_b_test_result_negative"] = filter_hash("hep_b_test_result", concept("Negative").concept_id)
          @data["hepatitis_b_test_result_positive"] = filter_hash("hep_b_test_result", concept("Positive").concept_id)

          @data["syphilis_test_result_negative"] = filter_hash("syphilis_test_result", concept("Negative").concept_id)
          @data["syphilis_test_result_positive"] = filter_hash("syphilis_test_result", concept("Positive").concept_id)
        end

        def fetch_hiv_tests
          @data["last_hiv_test_never_tested"] = filter_hash("previous_hiv_test", concept("Never Tested").concept_id)
          @data["last_hiv_test_negative_selftest"] = filter_hash("previous_hiv_test_done", concept("Self").concept_id).select { |q| q["previous_hiv_test"] == concept("Negative").concept_id }
          @data["last_hiv_test_negative_prof_test"] = filter_hash("previous_hiv_test_done", concept("Professional").concept_id).select { |q| q["previous_hiv_test"] == concept("Negative").concept_id }
          @data["last_hiv_test_positive_selftest"] = filter_hash("previous_hiv_test_done", concept("Self").concept_id).select { |q| [concept("Positive").concept_id, concept("Positive NOT on ART").concept_id, concept("Positive on ART").concept_id].include?(q["previous_hiv_test"]) }
          @data["last_hiv_test_positive_prof_test"] = filter_hash("previous_hiv_test_done", concept("Professional").concept_id).select { |q| [concept("Positive").concept_id, concept("Positive NOT on ART").concept_id, concept("Positive on ART").concept_id].include?(q["previous_hiv_test"]) }
          @data["last_hiv_test_positive_prof_initial_test"] = filter_hash("previous_hiv_test_done", concept("Initial professional").concept_id).select { |q| [concept("Positive").concept_id, concept("Positive NOT on ART").concept_id, concept("Positive on ART").concept_id].include?(q["previous_hiv_test"]) }
          @data["last_hiv_test_inconclusive_prof_test"] = filter_hash("previous_hiv_test_done", concept("Professional").concept_id).select { |q| q["previous_hiv_test"] == concept("Invalid or inconclusive").concept_id }
          @data["last_hiv_test_invalid_selftest"] = filter_hash("previous_hiv_test_done", concept("Self").concept_id).select { |q| q["previous_hiv_test"] == concept("Invalid or inconclusive").concept_id }
          @data["last_hiv_test_exposed_infant"] = filter_hash("previous_hiv_test", concept("Exposed infant").concept_id)

          @data["time_since_last_hiv_test_same_day"] = @query.select { |q| get_diff(q["obs_datetime"], q["time_of_hiv_test"]) <= 0 }
          @data["time_since_last_hiv_test_1_to_13_days"] = @query.select { |q| (1..13).include?(get_diff(q["obs_datetime"], q["time_of_hiv_test"])) }
          @data["time_since_last_hiv_test_35_months"] = @query.select { |q| (61..150).include?(get_diff(q["obs_datetime"], q["time_of_hiv_test"])) }
          @data["time_since_last_hiv_test_611_months"] = @query.select { |q| (151..330).include?(get_diff(q["obs_datetime"], q["time_of_hiv_test"])) }
          @data["time_since_last_hiv_test_14_days_to_2_months"] = @query.select { |q| (331..1000).include?(get_diff(q["obs_datetime"], q["time_of_hiv_test"])) }
          @data["time_since_last_hiv_test_12plus_months"] = @query.select { |q| get_diff(q["obs_datetime"], q["time_of_hiv_test"]) > 365 }
        end

        def fetch_risk_category
          @data["risk_category_low"] = filter_hash("risk_category", concept("Low risk").concept_id)
          @data["risk_category_ongoing"] = filter_hash("risk_category", concept("On-going risk").concept_id)
          @data["risk_category_highrisk_event"] = filter_hash("risk_category", concept("High risk event in last 3 months").concept_id)
          @data["risk_category_not_done"] = filter_hash("risk_category", concept("Risk assessment not done").concept_id)
        end

        def fetch_items_given
          @data["male_condoms_given_male_condoms_sum"] = @query.map { |q| q["male_condoms"] }.compact.sum
          @data["female_condoms_given_female_condoms_sum"] = @query.map { |q| q["female_condoms"] }.compact.sum
          @data["frs_given_family_referral_slips_sum"] = @query.map { |q| q["frs"] }.compact.sum
        end

        def fetch_ever_taken_drugs_before
          @data["ever_taken_arvs_no"] = filter_hash("taken_prep_before", NO_ANSWER)
          @data["ever_taken_arvs_prep"] = filter_hash("taken_prep_before", YES_ANSWER)
          @data["ever_taken_arvs_pep"] = filter_hash("taken_pep_before", YES_ANSWER)
          @data["ever_taken_arvs_art"] = filter_hash("taken_arvs_before", YES_ANSWER)
          @data["time_since_last_taken_arvs_same_day"] = @query.select { |q| get_diff(q["obs_datetime"], q["time_since_last_medication"]) <= 0 }
          @data["time_since_last_taken_arvs_1_to_13_days"] = @query.select { |q| (1..13).include?(get_diff(q["obs_datetime"], q["time_since_last_medication"])) }
          @data["time_since_last_taken_arvs_14_days_to_2_months"] = @query.select { |q| (14..60).include?(get_diff(q["obs_datetime"], q["time_since_last_medication"])) }
          @data["time_since_last_taken_arvs_35_months"] = @query.select { |q| (61..150).include?(get_diff(q["obs_datetime"], q["time_since_last_medication"])) }
          @data["time_since_last_taken_arvs_611_months"] = @query.select { |q| (151..330).include?(get_diff(q["obs_datetime"], q["time_since_last_medication"])) }
          @data["time_since_last_taken_arvs_12plus_months"] = @query.select { |q| (331..1000).include?(get_diff(q["obs_datetime"], q["time_since_last_medication"])) }
        end

        def fetch_partner_status
          @data["partner_present_yes"] = filter_hash("partner_present", "Yes")
          @data["partner_present_no"] = filter_hash("partner_present", "No")

          @data["partner_hiv_status_no_partner"] = filter_hash("partner_hiv_status", concept("No partner").concept_id)
          @data["partner_hiv_status_hiv_status_unknown"] = filter_hash("partner_hiv_status", concept("HIV unknown").concept_id)
          @data["partner_hiv_status_hiv_negative"] = filter_hash("partner_hiv_status", concept("Negative").concept_id)
          @data["partner_hiv_status_hiv_positive_art_unknown"] = filter_hash("partner_hiv_status", concept("Positive ART unknown").concept_id)
          @data["partner_hiv_status_hiv_positive_not_on_art"] = filter_hash("partner_hiv_status", concept("Positive NOT on ART").concept_id)
          @data["partner_hiv_status_hiv_positive_on_art"] = filter_hash("partner_hiv_status", concept("Positive on ART").concept_id)
        end

        def fetch_referral_retests
          @data["referral_for_hiv_retesting_no_retest_needed"] = filter_hash("referal_for_retesting", concept("NOT done").concept_id)
          @data["referral_for_hiv_retesting_retest_needed"] = filter_hash("referal_for_retesting", concept("Re-Test").concept_id)
          @data["referral_for_hiv_retesting_confirmatory_test"] = filter_hash("referal_for_retesting", concept("Confirmatory HIV test").concept_id)
        end

        def fetch_referrals
          @data["referral_for_vmmc"] = filter_hash("referrals_ordered", "VMMC")
          @data["referral_for_prep"] = filter_hash("referrals_ordered", "PrEP")
          @data["referral_for_sti"] = filter_hash("referrals_ordered", "STI")
          @data["referral_for_tb"] = filter_hash("referrals_ordered", "TB")
          @data["referral_for_pep"] = filter_hash("referrals_ordered", "PEP")
        end

        def linked_clients
          query = Patient.connection.select_all(
            his_patients_rev
              .joins("INNER JOIN obs o3 ON o3.person_id = encounter.patient_id AND o3.voided = 0 AND o3.concept_id = #{ConceptName.find_by_name("Hepatitis B Test Result").concept_id} AND encounter.encounter_id = o3.encounter_id")
              .joins(<<-SQL)
              LEFT JOIN obs linked ON linked.person_id = person.person_id
              AND linked.voided = 0
              AND linked.concept_id = #{ART_OUTCOME}
              SQL
              .select("person.person_id, max(linked.value_coded) as value_coded")
              .group("person.person_id").to_sql
          ).to_hash
          @data["linking_with_hiv_confirmatory_register_linked"] = query.select { |r| r["value_coded"] == LINKED_CONCEPT }
          @data["linking_with_hiv_confirmatory_register_not_applicable_not_linked"] = query.select { |r| r["value_coded"] != LINKED_CONCEPT }
        end
      end
    end
  end
end
