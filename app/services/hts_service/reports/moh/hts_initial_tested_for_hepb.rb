# frozen_string_literal: true

module HtsService
  module Reports
    module Moh
      # HTS Initial tested for hepb
      class HtsInitialTestedForHepb
        include HtsService::Reports::HtsReportBuilder
        attr_accessor :start_date, :end_date

        YES_ANSWER = concept("Yes").concept_id

        def initialize(start_date:, end_date:)
          @start_date = start_date
          @end_date = end_date
          @data = {

            'total_clients_tested_for_hepatitis_b' => [],
            'access_point_type_total_clients_tested_at_the_facility'=> [],
            'access_point_type_facility_vct' => [],
            'access_point_type_facility_anc_first_visit'=> [],
            'access_point_type_facility_inpatient' => [],
            'access_point_type_facility_sti' => [],
            'access_point_type_facility_pmtctfup'=> [],
            'access_point_type_facility_index'=> [],
            'access_point_type_facility_paediatric'=> [],
            'access_point_type_facility_vmmc'=> [],
            'access_point_type_facility_malnutrition'=> [],
            'access_point_type_facility_tb'=> [],
            'access_point_type_facility_opd'=> [],
            'access_point_type_facility_other_pitc'=> [],
            'access_point_type_facility_sns'=> [],
            'access_point_type_total_clients_tested_in_the_community'=> [],
            'access_point_type_community_vmmc'=> [],
            'access_point_type_community_index'=> [],
            'access_point_type_community_mobile'=> [],
            'access_point_type_community_vct'=> [],
            'access_point_type_community_other'=> [],
            'access_point_type_community_sns'=> [],
            'access_point_type_invalid_entry'=> [],
            'access_point_type_missing'=> [],
            'sex_or_pregnancy_total_males'=> [],
            'sex_or_pregnancy_male_circumcised' => [],
            'sex_or_pregnancy_male_noncircumcised'=> [],
            'sex_or_pregnancy_total_females'=> [],
            'sex_or_pregnancy_female_nonpregnant'=> [],
            'sex_or_pregnancy_female_pregnant'=> [],
            'sex_or_pregnancy_female_breastfeeding'=> [],
            'sex_or_pregnancy_invalid_entry'=> [],
            'sex_or_pregnancy_missing'=> [],
            'age_group_years_a_under_1'=> [],
            'age_group_years_b_114'=> [],
            'age_group_years_c_1524'=> [],
            'age_group_years_d_25plus'=> [],
            'age_group_years_missing'=> [],
            'last_hiv_test_never_tested' => [],
            'last_hiv_test_negative_selftest'=> [],
            'last_hiv_test_negative_prof_test'=> [],
            'last_hiv_test_positive_selftest'=> [],
            'last_hiv_test_positive_prof_initial_test' => [],
            'last_hiv_test_invalid_self_test'=> [],
            'last_hiv_test_positive_prof_test'=> [],
            'last_hiv_test_invalid_selftest'=> [],
            'last_hiv_test_inconclusive_prof_test'=> [],
            'last_hiv_test_exposed_infant'=> [],
            'last_hiv_test_invalid_entry'=> [],
            'last_hiv_test_missing'=> [],
            'time_since_last_hiv_test_12plus_months'=> [],
            'time_since_last_hiv_test_611_months'=> [],
            'time_since_last_hiv_test_35_months'=> [],
            'time_since_last_hiv_test_14_days_to_2_months' => [],
            'time_since_last_hiv_test_1_to_13_days'=> [],
            'time_since_last_hiv_test_same_day'=> [],
           'time_since_last_hiv_test_invalid_entry'=> [],
           'time_since_last_hiv_test_not_applicable_or_missing'=> [],
           'ever_taken_arvs_no'=> [],
           'ever_taken_arvs_prep'=> [],
           'ever_taken_arvs_pep'=> [],
           'ever_taken_arvs_art'=> [],
           'ever_taken_arvs_invalid_entry'=> [],
           'ever_taken_arvs_missing'=> [],
           'time_since_last_taken_arvs_12plus_months'=> [],
           'time_since_last_taken_arvs_611_months'=> [],
           'time_since_last_taken_arvs_35_months'=> [],
           'time_since_last_taken_arvs_14_days_to_2_months'=> [],
           'time_since_last_taken_arvs_1_to_13_days'=> [],
           'time_since_last_taken_arvs_same_day'=> [],
           'time_since_last_taken_arvs_invalid_entry'=> [],
           'time_since_last_taken_arvs_not_applicable_or_missing'=> [],
           'risk_category_low'=> [],
           'risk_category_ongoing' => [],
           'risk_category_highrisk_event'=> [],
           'risk_category_not_done'=> [],
           'risk_category_invalid_entry'=> [],
           'risk_category_missing'=> [],
           'hiv_test_1_result_negative' => [],
           'hiv_test_1_result_positive'=> [],
           'hiv_test_1_result_not_done'=> [],
           'hiv_test_1_result_invalid_entry' => [],
           'hiv_test_1_result_missing' => [],
           'hepatitis_b_test_result_negative'=> [],
           'hepatitis_b_test_result_positive'=> [],
           'hepatitis_b_test_result_not_done'=> [],
           'hepatitis_b_test_result_invalid_entry'=> [],
           'hepatitis_b_test_result_missing' => [],
           'syphilis_test_result_negative'=> [],
           'syphilis_test_result_positive' => [],
           'syphilis_test_result_not_done' => [],
           'syphilis_test_result_invalid_entry' => [],
           'syphilis_test_result_missing' => [],
           'partner_present_yes'=> [],
           'partner_present_no'=> [],
           'partner_present_invalid_entry'=> [],
           'partner_present_missing' => [],
           'partner_hiv_status_no_partner'=> [],
           'partner_hiv_status_hiv_status_unknown'=> [],
           'partner_hiv_status_hiv_negative'=> [],
           'partner_hiv_status_hiv_positive_art_unknown'=> [],
           'partner_hiv_status_hiv_positive_not_on_art'=> [],
           'partner_hiv_status_hiv_positive_on_art'=> [],
           'partner_hiv_status_invalid_entry'=> [],
           'partner_hiv_status_missing'=> [],
           'referral_for_hiv_retesting_no_retest_needed'=> [],
           'referral_for_hiv_retesting_retest_needed' => [],
           'referral_for_hiv_retesting_confirmatory_test'=> [],
           'referral_for_hiv_retesting_invalid_entry'=> [],
           'referral_for_hiv_retesting_missing'=> [],
           'referral_for_vmmc' => [],
            'referral_for_prep' => [],
            'referral_for_sti' => [],
            'referral_for_tb' => [],
            'referral_for_pep' => [],
           'referral_for_prep_invalid_entry'=> [],
           'referral_for_prep_missing'=> [],
           'referral_for_prep' => [],
           'referral_for_pep' => [],
           'referral_for_vmmc' => [],
           'referral_for_sti' => [],
           'referral_for_tb' => [],
           'referral_invalid_entry' => [],
           'referral_missing' => [],
           'frs_given_family_referral_slips_sum'=> [],
           'frs_given_invalid_entry' => [],
           'male_condoms_given_male_condoms_sum'=> [],
           'male_condoms_given_invalid_entry' => [],
           'female_condoms_given_female_condoms_sum' => [],
           'female_condoms_given_invalid_entry' => [],
           'linking_with_hiv_confirmatory_register_total_clients_hiv_test_1_positive' => [],
           'linking_with_hiv_confirmatory_register_linked' => [],
           'linking_with_hiv_confirmatory_register_missing_linkid_not_in_conf_register'=> [],
           'linking_with_hiv_confirmatory_register_total_clients_hiv_test_1_negative'=> [],
           'linking_with_hiv_confirmatory_register_not_applicable_not_linked' => [],
           'linking_with_hiv_confirmatory_register_invalid_linkid_in_conf_register' => [],
           'linking_with_hiv_confirmatory_register_total_clients_hiv_test_1_not_done' => [],
          "last_hiv_test_positive_prof_initial_test"=>[],

        }
        end

        def data
          report = init_report
          response = @data
        end

        private

        def init_report

          fetch_hepatitis_b_clients
          fetch_hiv_tests
          fetch_drugs_taken
          fetch_partner_status
          fetch_referral_retests
          linked_clients
          fetch_risk_category
          fetch_referrals
          fetch_ever_taken_drugs_before
          fetch_items_given
          set_unique

        end
        def set_unique

          @data.each do |key, array|
            unless %i[
              frs_given_family_referral_slips_sum male_condoms_given_male_condoms_sum female_condoms_given_female_condoms_sum
            ].include?(key)
              @data[key] = array
              next
            end
              @data[key]  =  array.uniq
          end

        end


        def fetch_hepatitis_b_clients

          Person.joins("INNER JOIN encounter e ON e.patient_id = person.person_id AND e.encounter_type = #{EncounterType.find_by_name("TESTING").encounter_type_id} AND e.voided = 0 AND e.program_id = #{Program.find_by_name("HTC Program").program_id}")
                .joins("INNER JOIN obs o1 ON o1.person_id = e.patient_id AND o1.voided = 0 AND o1.concept_id = #{ConceptName.find_by_name('HTS Access Type').concept_id} AND e.encounter_id = o1.encounter_id")
                .joins("INNER JOIN obs o2 ON o2.person_id = e.patient_id AND o2.voided = 0 AND o2.concept_id = #{ConceptName.find_by_name('Location where test took place').concept_id} AND e.encounter_id = o2.encounter_id")
                .joins("INNER JOIN obs o3 ON o3.person_id = e.patient_id AND o3.voided = 0 AND o3.concept_id = #{ConceptName.find_by_name('Hepatitis B Test Result').concept_id} AND e.encounter_id = o3.encounter_id")
                .select("person.person_id person_id,person.gender gender,person.birthdate dob,o1.value_coded concept_id,o2.value_text value,o2.encounter_id encounter_id,o3.value_coded results")
                .where("person.voided = 0 AND DATE(e.encounter_datetime) BETWEEN '#{start_date}' AND '#{end_date}' + INTERVAL 1 DAY")
                .each do |client|

                    @data["total_clients_tested_for_hepatitis_b"].push(client.person_id) if client.results != nil
                    @data['access_point_type_total_clients_tested_at_the_facility'].push(client.person_id) if ConceptName.find_by_name('Health facility').concept_id == client.concept_id
                    @data['access_point_type_total_clients_tested_in_the_community'].push(client.person_id) if ConceptName.find_by_name('Community').concept_id == client.concept_id
                    @data['access_point_type_facility_vct'].push(client.person_id) if client.value == "VCT" && ConceptName.find_by_name('Health facility').concept_id == client.concept_id
                    @data['access_point_type_facility_anc_first_visit'].push(client.person_id) if client.value == "ANC First Visit" && ConceptName.find_by_name('Health facility').concept_id == client.concept_id
                    @data['access_point_type_facility_inpatient'].push(client.person_id) if client.value == "Inpatient" && ConceptName.find_by_name('Health facility').concept_id == client.concept_id
                    @data['access_point_type_facility_sti'].push(client.person_id) if client.value == "STI" && ConceptName.find_by_name('Health facility').concept_id == client.concept_id
                    @data['access_point_type_facility_pmtct_fup'].push(client.person_id) if client.value == "PMTCT FUP" && ConceptName.find_by_name('Health facility').concept_id == client.concept_id
                    @data['access_point_type_facility_index'].push(client.person_id) if client.value == "Index" && ConceptName.find_by_name('Health facility').concept_id == client.concept_id
                    @data['access_point_type_facility_paediatric'].push(client.person_id) if client.value == "Paediatric" && ConceptName.find_by_name('Health facility').concept_id == client.concept_id
                    @data['access_point_type_facility_malnutrition'].push(client.person_id) if client.value == "Malnutrition" && ConceptName.find_by_name('Health facility').concept_id == client.concept_id
                    @data['access_point_type_facility_vmmc'].push(client.person_id) if client.value == "VMMC" && ConceptName.find_by_name('Health facility').concept_id == client.concept_id
                    @data['access_point_type_facility_tb'].push(client.person_id) if client.value == "TB" && ConceptName.find_by_name('Health facility').concept_id == client.concept_id
                    @data['access_point_type_facility_opd'].push(client.person_id) if client.value == "OPD" && ConceptName.find_by_name('Health facility').concept_id == client.concept_id
                    @data['access_point_type_facility_other_pitc'].push(client.person_id) if client.value == "Other PITC" && ConceptName.find_by_name('Health facility').concept_id == client.concept_id
                    @data['access_point_type_facility_sns'].push(client.person_id) if client.value == "SNS" && ConceptName.find_by_name('Health facility').concept_id == client.concept_id
                    @data['access_point_type_community_vmmc'].push(client.person_id) if client.value == "VMMC" && ConceptName.find_by_name('Community').concept_id == client.concept_id
                    @data['access_point_type_community_index'].push(client.person_id) if client.value == "Index" && ConceptName.find_by_name('Community').concept_id == client.concept_id
                    @data['access_point_type_community_mobile'].push(client.person_id) if client.value == "Mobile" && ConceptName.find_by_name('Community').concept_id == client.concept_id
                    @data['access_point_type_community_vct'].push(client.person_id) if client.value == "VCT" && ConceptName.find_by_name('Community').concept_id == client.concept_id
                    @data['access_point_type_community_other'].push(client.person_id) if client.value == "Other" && ConceptName.find_by_name('Community').concept_id == client.concept_id
                    @data['access_point_type_community_sns'].push(client.person_id) if client.value == "SNS" && ConceptName.find_by_name('Community').concept_id == client.concept_id
                    @data['access_point_type_invalid_entry'].push(client.person_id) if client.value == "Other" && ConceptName.find_by_name('Community').concept_id == client.concept_id
                    @data['access_point_type_missing'].push(client.person_id) if client.value == "SNS" && ConceptName.find_by_name('Community').concept_id == client.concept_id

                    @data['sex_or_pregnancy_total_males'].push(client.person_id) if client.gender == "M"
                    @data['sex_or_pregnancy_total_females'].push(client.person_id) if client.gender == "F"

                     date  = (Date.today.strftime('%Y%m%d').to_i - client.dob.strftime('%Y%m%d').to_i) / 10000
                     @data['age_group_years_a_under_1'].push(client.person_id) if date < 1
                     @data['age_group_years_b_114'].push(client.person_id) if date > 0 && date < 15
                     @data['age_group_years_c_1524'].push(client.person_id) if date > 14 && date < 25
                     @data['age_group_years_d_25plus'].push(client.person_id) if date > 24

                    status = Observation.joins(:encounter)\
                          .where(concept: concept('Circumcision status'),
                                  person: client.person_id,
                               encounter: { encounter_type: EncounterType.find_by_name("CIRCUMCISION").encounter_type_id,
                                                program_id: Program.find_by_name("HTC Program").program_id })\
                          .where("encounter_datetime BETWEEN '#{start_date}' AND '#{end_date}' + INTERVAL 1 DAY ")\
                          .last

                    unless status.blank?

                       @data['sex_or_pregnancy_male_circumcised'].push(client.person_id) if ConceptName.find_by_name('Yes').concept_id == status.value_coded
                       @data['sex_or_pregnancy_male_noncircumcised'].push(client.person_id) if ConceptName.find_by_name('No').concept_id == status.value_coded

                    end

                    Person.joins("INNER JOIN encounter e ON e.patient_id = person.person_id AND e.encounter_type = #{EncounterType.find_by_name("PREGNANCY STATUS").encounter_type_id} AND e.voided = 0 AND e.program_id = #{Program.find_by_name("HTC Program").program_id}")
                    .joins("INNER JOIN obs ON obs.person_id = e.patient_id AND obs.voided = 0 AND obs.concept_id = #{ConceptName.find_by_name('Pregnancy status').concept_id} AND e.encounter_id = obs.encounter_id")
                    .joins("INNER JOIN obs o3 ON o3.person_id = e.patient_id AND o3.voided = 0 AND o3.concept_id = #{ConceptName.find_by_name('Hepatitis B Test Result').concept_id} AND e.encounter_id = o3.encounter_id")
                    .select("person.person_id person_id,obs.encounter_id encounter_id,obs.value_coded concept_id")
                    .where("person.voided = 0 AND person.person_id = '#{client.person_id}' AND DATE(e.encounter_datetime) BETWEEN '#{start_date}' AND '#{end_date}' + INTERVAL 1 DAY")
                    .each do |values|

                      @data['sex_or_pregnancy_female_nonpregnant'].push(values.person_id) if ConceptName.find_by_name('Not Pregnant / Breastfeeding').concept_id == values.concept_id
                      @data['sex_or_pregnancy_female_pregnant'].push(values.person_id) if ConceptName.find_by_name('Patient pregnant').concept_id == values.concept_id
                      @data['sex_or_pregnancy_female_breastfeeding'].push(values.person_id) if ConceptName.find_by_name('Breastfeeding').concept_id == values.concept_id


                    end

                    Observation.where(encounter_id:client.encounter_id).each do |tests|

                            if ConceptName.find_by_name("Test 1").concept_id == tests.concept_id
                              @data["hiv_test_1_result_negative"].push(client.person_id) if ConceptName.find_by_name('Negative').concept_id == tests.value_coded
                              @data["hiv_test_1_result_positive"].push(client.person_id) if ConceptName.find_by_name('Positive').concept_id == tests.value_coded
                              @data["linking_with_hiv_confirmatory_register_total_clients_hiv_test_1_negative"].push(tests.person_id) if ConceptName.find_by_name('Negative').concept_id == tests.value_coded
                              @data["linking_with_hiv_confirmatory_register_total_clients_hiv_test_1_positive"].push(tests.person_id) if ConceptName.find_by_name('Positive').concept_id == tests.value_coded

                            end

                            if ConceptName.find_by_name('Hepatitis B Test Result').concept_id == tests.concept_id
                                @data["hepatitis_b_test_result_negative"].push(client.person_id) if ConceptName.find_by_name('Negative').concept_id == tests.value_coded
                                @data["hepatitis_b_test_result_positive"].push(client.person_id) if ConceptName.find_by_name('Positive').concept_id == tests.value_coded
                            end

                           if ConceptName.find_by_name('Syphilis Test Result').concept_id == tests.concept_id
                             @data["syphilis_test_result_negative"].push(client.person_id) if ConceptName.find_by_name('Negative').concept_id == tests.value_coded
                             @data["syphilis_test_result_positive"].push(client.person_id) if ConceptName.find_by_name('Positive').concept_id == tests.value_coded
                          end
                    end



            end
        end

        def fetch_hiv_tests

          Person.joins("INNER JOIN encounter e ON e.patient_id = person.person_id AND e.encounter_type = #{EncounterType.find_by_name("TESTING").encounter_type_id} AND e.voided = 0 AND e.program_id = #{Program.find_by_name("HTC Program").program_id}")
                .joins("INNER JOIN obs o1 ON o1.person_id = e.patient_id AND o1.voided = 0 AND o1.concept_id = #{ConceptName.find_by_name('Time of HIV test').concept_id} AND e.encounter_id = o1.encounter_id")
                .joins("INNER JOIN obs o2 ON o2.person_id = e.patient_id AND o2.voided = 0 AND o2.concept_id = #{ConceptName.find_by_name('Previous HIV Test Results').concept_id} AND e.encounter_id = o2.encounter_id")
                .joins("INNER JOIN obs o3 ON o3.person_id = e.patient_id AND o3.voided = 0 AND o3.concept_id = #{ConceptName.find_by_name('Previous HIV Test done').concept_id} AND e.encounter_id = o3.encounter_id")
                .joins("INNER JOIN obs o4 ON o4.person_id = e.patient_id AND o4.voided = 0 AND o4.concept_id = #{ConceptName.find_by_name('Hepatitis B Test Result').concept_id} AND e.encounter_id = o4.encounter_id")
                .select("person.person_id person_id,person.gender gender,o1.value_text value,o2.value_coded concept_id,o3.value_coded o3concept_id")
                .where("person.voided = 0 AND DATE(e.encounter_datetime) BETWEEN '#{start_date}' AND '#{end_date}' + INTERVAL 1 DAY")
                .each do |client|

                  @data['last_hiv_test_never_tested'].push(client.person_id) if ConceptName.find_by_name('Never Tested').concept_id == client.concept_id
                  @data['last_hiv_test_negative_selftest'].push(client.person_id) if ConceptName.find_by_name('Self').concept_id == client.o3concept_id && ConceptName.find_by_name('Negative').concept_id == client.concept_id
                  @data["last_hiv_test_negative_prof_test"].push(client.person_id) if ConceptName.find_by_name('Professional').concept_id == client.o3concept_id && ConceptName.find_by_name('Negative').concept_id == client.concept_id
                  @data["last_hiv_test_positive_selftest"].push(client.person_id) if ConceptName.find_by_name('Self').concept_id == client.o3concept_id && ConceptName.find_by_name('Positive').concept_id == client.concept_id
                  @data["last_hiv_test_positive_prof_test"].push(client.person_id) if ConceptName.find_by_name('Professional').concept_id == client.o3concept_id && ConceptName.find_by_name('Positive').concept_id == client.concept_id
                  @data["last_hiv_test_inconclusive_prof_test"].push(client.person_id) if ConceptName.find_by_name('Professional').concept_id == client.o3concept_id && ConceptName.find_by_name('Inconclusive').concept_id == client.concept_id
                  @data["last_hiv_test_exposed_infant"].push(client.person_id) if ConceptName.find_by_name('Self').concept_id == client.o3concept_id && ConceptName.find_by_name('Exposed Infant').concept_id == client.concept_id
                  @data["last_hiv_test_positive_prof_initial_test"].push(client.person_id) if ConceptName.find_by_name('Initial Professional').concept_id == client.o3concept_id && ConceptName.find_by_name('Positive').concept_id == client.concept_id

                  array = client.value.to_s.split(" ")
                  case array[1].to_s

                    when "Days"

                    @data["time_since_last_hiv_test_same_day"].push(client.person_id) if array[0].to_i == 1
                    @data["time_since_last_hiv_test_1_to_13_days"].push(client.person_id) if array[0].to_i > 1 && array[0].to_i < 14
                    @data["time_since_last_hiv_test_14_days_to_2_months"].push(client.person_id) if array[0].to_i > 13 && array[0].to_i < 61
                    @data["time_since_last_hiv_test_35_months"].push(client.person_id) if array[0].to_i > 60 && array[0].to_i < 150
                    @data["time_since_last_hiv_test_611_months"].push(client.person_id) if array[0].to_i > 149 && array[0].to_i < 330
                    @data["time_since_last_hiv_test_12plus_months"].push(client.person_id) if array[0].to_i > 329

                    when "Months"

                    @data["time_since_last_hiv_test_14_days_to_2_months"].push(client.person_id) if array[0].to_i < 3
                    @data["time_since_last_hiv_test_35_months"].push(client.person_id) if array[0].to_i > 2 && array[0].to_i < 6
                    @data["time_since_last_hiv_test_611_months"].push(client.person_id) if array[0].to_i > 5 && array[0].to_i < 12
                    @data["time_since_last_hiv_test_12plus_months"].push(client.person_id) if array[0].to_i > 11

                  end


                end
        end


        def fetch_risk_category
          Person.joins(:observations, patient: :encounters)
            .joins("INNER JOIN concept_name cn ON cn.concept_id = obs.value_coded and cn.voided = 0")
            .joins("INNER JOIN obs o4 ON o4.person_id = patient.patient_id AND o4.voided = 0 AND o4.concept_id = #{ConceptName.find_by_name('Hepatitis B Test Result').concept_id} AND encounter.encounter_id = o4.encounter_id")
            .where(
              encounter: { encounter_type: EncounterType.find_by_name("TESTING").encounter_type_id,
                            encounter_datetime: start_date..end_date,
                            program_id: Program.find_by_name("HTC Program").program_id },
              obs: { concept_id: ConceptName.find_by_name("client risk category").concept_id },
            ).select("person.person_id, cn.name as category")
            .each do |client|
                  @data["risk_category_low"].push(client.person_id) if client.category == "Low risk"
                  @data["risk_category_ongoing"].push(client.person_id) if client.category == "On-going risk"
                  @data["risk_category_highrisk_event"].push(client.person_id) if client.category == "High risk event in last 3 months"
                  @data["risk_category_not_done"].push(client.person_id) if client.category == "Risk assessment not done"
            end
        end

        def fetch_items_given
            Person.joins(patient: :encounters)
            .joins("INNER JOIN obs o4 ON o4.person_id = patient.patient_id AND o4.voided = 0 AND o4.concept_id = #{ConceptName.find_by_name('Hepatitis B Test Result').concept_id} AND encounter.encounter_id = o4.encounter_id")
            .joins(<<~SQL)
              LEFT JOIN obs male_condoms on male_condoms.person_id = person.person_id
              AND male_condoms.concept_id = #{concept('Male Condoms').concept_id}
              AND male_condoms.voided = 0
              LEFT JOIN obs female_condoms on female_condoms.person_id = person.person_id
              AND female_condoms.concept_id = #{concept('Female Condoms').concept_id}
              AND female_condoms.voided = 0  
              LEFT JOIN obs frs on frs.person_id = person.person_id
              AND frs.concept_id = #{concept('FRS').concept_id}
              AND frs.voided = 0
            SQL
            .where(
              encounter: { encounter_type: EncounterType.find_by_name("TESTING").encounter_type_id,
                            encounter_datetime: start_date..end_date,
                            program_id: Program.find_by_name("HTC Program").program_id },
            ).select("person.person_id, male_condoms.value_numeric male_condoms, female_condoms.value_numeric female_condoms, frs.value_numeric frs")
            .each do |client|
              if client.male_condoms.present?
                client.male_condoms.to_i.times do
                  @data["male_condoms_given_male_condoms_sum"].push(client.patient.id)
                end
              end
              if  client.female_condoms.present?
                client.female_condoms.to_i.times do
                  @data["female_condoms_given_female_condoms_sum"].push(client.patient.id)
                end
              end
              if  client.frs.present?
                client.frs.to_i.times do
                  @data["frs_given_frs_sum"].push(client.patient.id)
                end
              end
            end
        end

        def fetch_ever_taken_drugs_before
           Person.joins(:observations, patient: :encounters)
            .joins("INNER JOIN obs o5 ON o5.person_id = encounter.patient_id AND o5.voided = 0 AND o5.concept_id = #{ConceptName.find_by_name('Hepatitis B Test Result').concept_id} AND encounter.encounter_id = o5.encounter_id")
            .joins(<<~SQL)
              LEFT JOIN obs taken_arv on taken_arv.person_id = person.person_id 
              AND taken_arv.concept_id = #{concept('Taken ARV before').concept_id}
              AND taken_arv.voided = 0
              LEFT JOIN obs taken_prep on taken_prep.person_id = person.person_id 
              AND taken_prep.concept_id = #{concept('Taken PrEP before').concept_id}
              AND taken_prep.voided = 0
              LEFT JOIN obs taken_pep on taken_pep.person_id = person.person_id 
              AND taken_pep.concept_id = #{concept('Taken PEP before').concept_id}
              AND taken_pep.voided = 0
            SQL
            .where(
              encounter: { encounter_type: EncounterType.find_by_name("TESTING").encounter_type_id,
                            encounter_datetime: start_date..end_date,
                            program_id: Program.find_by_name("HTC Program").program_id }
            )
            .select("person.person_id person_id,person.gender gender,taken_arv.value_coded taken_arv,taken_prep.value_coded taken_prep,taken_pep.value_coded taken_pep")
            .group("person.person_id")
            .each do |client|
              @data["ever_taken_arvs_art"].push(client.person_id) if client.taken_arv == YES_ANSWER
              @data["ever_taken_arvs_prep"].push(client.person_id) if client.taken_prep == YES_ANSWER
              @data["ever_taken_arvs_pep"].push(client.person_id) if client.taken_pep == YES_ANSWER
              @data["ever_taken_arvs_no"].push(client.person_id) if client.taken_arv != YES_ANSWER && client.taken_prep != YES_ANSWER && client.taken_pep != YES_ANSWER
            end
        end
      
        def fetch_drugs_taken

          Person.joins("INNER JOIN encounter e ON e.patient_id = person.person_id AND e.encounter_type = #{EncounterType.find_by_name("TESTING").encounter_type_id} AND e.voided = 0 AND e.program_id = #{Program.find_by_name("HTC Program").program_id}")
                .joins("INNER JOIN obs o1 ON o1.person_id = e.patient_id AND o1.voided = 0 AND o1.concept_id = #{ConceptName.find_by_name('Antiretroviral medication history').concept_id} AND e.encounter_id = o1.encounter_id")
                .joins("INNER JOIN obs o3 ON o3.person_id = e.patient_id AND o3.voided = 0 AND o3.concept_id = #{ConceptName.find_by_name('Hepatitis B Test Result').concept_id} AND e.encounter_id = o3.encounter_id")
                .select("person.person_id person_id,person.gender gender,o1.value_coded concept_id,o1.encounter_id encounterid")
                .where("person.voided = 0 AND DATE(e.encounter_datetime) BETWEEN '#{start_date}' AND '#{end_date}' + INTERVAL 1 DAY")
                .each do |client|

                    if ConceptName.find_by_name('No').concept_id == client.concept_id

                        @data["ever_taken_arvs_no"].push(client.person_id)

                    elsif ConceptName.find_by_name('Yes').concept_id == client.concept_id

                            Observation.where(encounter_id:client.encounterid,
                                                 person_id:client.person_id).each do |drug|

                                  if ConceptName.find_by_name("Given drugs").concept_id == drug.concept_id

                                       @data["ever_taken_arvs_prep"].push(client.person_id) if ConceptName.find_by_name('Prep or infant NVP').concept_id == drug.value_coded
                                       @data["ever_taken_arvs_pep"].push(client.person_id) if ConceptName.find_by_name('PEP').concept_id == drug.value_coded
                                       @data["ever_taken_arvs_art"].push(client.person_id) if ConceptName.find_by_name('ARV').concept_id == drug.value_coded

                                  end
                                  if ConceptName.find_by_name("Time since last taken medication").concept_id == drug.concept_id

                                        array = drug.value_text.to_s.split(" ")
                                       case array[1].to_s

                                            when "Days"

                                                 @data["time_since_last_taken_arvs_same_day"].push(client.person_id) if array[0].to_i == 1
                                                 @data["time_since_last_taken_arvs_1_to_13_days"].push(client.person_id) if array[0].to_i > 1 && array[0].to_i < 14
                                                 @data["time_since_last_taken_arvs_14_days_to_2_months"].push(client.person_id) if array[0].to_i > 13 && array[0].to_i < 61
                                                 @data["time_since_last_taken_arvs_35_months"].push(client.person_id) if array[0].to_i > 60 && array[0].to_i < 150
                                                 @data["time_since_last_taken_arvs_611_months"].push(client.person_id) if array[0].to_i > 149 && array[0].to_i < 330
                                                 @data["time_since_last_taken_arvs_12plus_months"].push(client.person_id) if array[0].to_i > 329

                                            when "Months"

                                                @data["time_since_last_taken_arvs_14_days_to_2_months"].push(client.person_id) if array[0].to_i < 3
                                                @data["time_since_last_taken_arvs_35_months"].push(client.person_id) if array[0].to_i > 2 && array[0].to_i < 6
                                                @data["time_since_last_taken_arvs_611_months"].push(client.person_id) if array[0].to_i > 5 && array[0].to_i < 12
                                                @data["time_since_last_taken_arvs_12plus_months"].push(client.person_id) if array[0].to_i > 11

                                            when "Years"

                                              @data["time_since_last_taken_arvs_12plus_months"].push(client.person_id)
                                        end

                                  end
                            end



                      end
                end
            end


        def fetch_partner_status

          Person.joins("INNER JOIN encounter e ON e.patient_id = person.person_id AND e.encounter_type = #{EncounterType.find_by_name("Partner Reception").encounter_type_id} AND e.voided = 0 AND e.program_id = #{Program.find_by_name("HTC Program").program_id}")
                .joins("INNER JOIN obs ON obs.person_id = e.patient_id AND obs.voided = 0 AND obs.concept_id = #{ConceptName.find_by_name('Partner Present').concept_id} AND e.encounter_id = obs.encounter_id")
                .joins("INNER JOIN obs o3 ON o3.person_id = e.patient_id AND o3.voided = 0 AND o3.concept_id = #{ConceptName.find_by_name('Hepatitis B Test Result').concept_id} AND e.encounter_id = o3.encounter_id")
                .select("person.person_id person_id,person.gender gender,obs.value_text value,obs.encounter_id encounter_id")
                .where("person.voided = 0 AND DATE(e.encounter_datetime) BETWEEN '#{start_date}' AND '#{end_date}' + INTERVAL 1 DAY")
                .each do |client|

                     @data['partner_present_yes'].push(client.person_id) if client.value == "Yes"
                     @data["partner_present_no"].push(client.person_id) if client.value == "No"

                    Observation.where(encounter_id:client.encounter_id,
                                         person_id:client.person_id,
                                        concept_id:"#{ConceptName.find_by_name("Partner HIV Status").concept_id}").each do |status|

                          @data["partner_hiv_status_no_partner"].push(client.person_id) if client.value == "No"
                          @data["partner_hiv_status_hiv_status_unknown"].push(client.person_id) if ConceptName.find_by_name('HIV unknown').concept_id == status.value_coded
                          @data["partner_hiv_status_hiv_negative"].push(client.person_id) if ConceptName.find_by_name('Negative').concept_id == status.value_coded
                          @data["partner_hiv_status_hiv_positive_art_unknown"].push(client.person_id) if ConceptName.find_by_name('Positive Art unknown').concept_id == status.value_coded
                          @data["partner_hiv_status_hiv_positive_not_on_art"].push(client.person_id) if ConceptName.find_by_name('Positive NOT on ART').concept_id == status.value_coded
                          @data["partner_hiv_status_hiv_positive_on_art"].push(client.person_id) if ConceptName.find_by_name('Positive on ART').concept_id == status.value_coded
                     end

              end
        end

        def fetch_referral_retests

          Person.joins("INNER JOIN encounter e ON e.patient_id = person.person_id AND e.encounter_type = #{EncounterType.find_by_name("APPOINTMENT").encounter_type_id} AND e.voided = 0 AND e.program_id = #{Program.find_by_name("HTC Program").program_id}")
                .joins("INNER JOIN obs ON obs.person_id = e.patient_id AND obs.voided = 0 AND obs.concept_id = #{ConceptName.find_by_name('Referral for Re-Testing').concept_id} AND e.encounter_id = obs.encounter_id")
                .joins("INNER JOIN obs o3 ON o3.person_id = e.patient_id AND o3.voided = 0 AND o3.concept_id = #{ConceptName.find_by_name('Hepatitis B Test Result').concept_id} AND e.encounter_id = o3.encounter_id")
                .select("person.person_id person_id,person.gender gender,obs.value_text value")
                .where("person.voided = 0 AND DATE(e.encounter_datetime) BETWEEN '#{start_date}' AND '#{end_date}' + INTERVAL 1 DAY")
                .each do |client|

                     @data['referral_for_hiv_retesting_no_retest_needed'].push(client.person_id) if client.value == 'None'
                     @data['referral_for_hiv_retesting_retest_needed'].push(client.person_id) if client.value == 'Re-Test'
                     @data['referral_for_hiv_retesting_confirmatory_test'].push(client.person_id) if client.value == 'Confirmatory Test'
                     @data['referral_for_hiv_retesting_invalid_entry'].push(client.person_id) if client.value == nil
                     @data['referral_for_hiv_retesting_missing'].push(client.person_id) if client.value == nil

              end
        end

        def fetch_referrals

          Person.joins("INNER JOIN encounter e ON e.patient_id = person.person_id AND e.encounter_type = #{EncounterType.find_by_name("TESTING").encounter_type_id} AND e.voided = 0 AND e.program_id = #{Program.find_by_name("HTC Program").program_id}")
          .joins("INNER JOIN obs o1 ON o1.person_id = e.patient_id AND o1.voided = 0 AND o1.concept_id = #{ConceptName.find_by_name('HIV status').concept_id} AND o1.value_coded = #{ConceptName.find_by_name('Positive').concept_id} AND e.encounter_id = o1.encounter_id")
          .joins("INNER JOIN obs o3 ON o3.person_id = e.patient_id AND o3.voided = 0 AND o3.concept_id = #{ConceptName.find_by_name('Hepatitis B Test Result').concept_id} AND e.encounter_id = o3.encounter_id")
          .select("person.person_id person_id")
          .where("person.voided = 0 AND DATE(e.encounter_datetime) BETWEEN '#{start_date}' AND '#{end_date}' + INTERVAL 1 DAY")
          .each do |client|

           Observation.joins(:encounter)\
                             .where(concept: concept('Referrals ordered'),
                                     person: client.person_id,
                 encounter: { encounter_type: EncounterType.find_by_name("REFERRAL").encounter_type_id,
                                  program_id: Program.find_by_name("HTC Program").program_id })\
            .select("obs.value_text value")\
            .where("encounter_datetime BETWEEN '#{start_date}' AND '#{end_date}' + INTERVAL 1 DAY ")\
            .each do |obs|
                  @data['referral_for_vmmc'].push(client.person_id) if obs.value&.strip == "VMMC"
                  @data['referral_for_prep'].push(client.person_id) if obs.value&.strip == 'PrEP'
                  @data['referral_for_sti'].push(client.person_id) if obs.value&.strip == 'STI'
                  @data['referral_for_tb'].push(client.person_id) if obs.value&.strip == 'TB'
                  @data['referral_for_pep'].push(client.person_id) if obs.value&.strip == 'PEP'

              end

             end

          end
       

       def linked_clients

        query = Patient.connection.select_all(
            his_patients_rev
              .joins("INNER JOIN obs o3 ON o3.person_id = encounter.patient_id AND o3.voided = 0 AND o3.concept_id = #{ConceptName.find_by_name('Hepatitis B Test Result').concept_id} AND encounter.encounter_id = o3.encounter_id")
              .joins(<<-SQL)
              LEFT JOIN obs linked ON linked.person_id = person.person_id
              AND linked.voided = 0
              AND linked.concept_id = #{ART_OUTCOME}
              SQL
              .select("person.person_id, max(linked.value_coded) as value_coded")
              .group("person.person_id").to_sql
          ).to_hash
          @data["linking_with_hiv_confirmatory_register_linked"] = query.select { |r| r["value_coded"] == LINKED_CONCEPT }.map { |r| r["person_id"] }
          @data["linking_with_hiv_confirmatory_register_not_applicable_not_linked"] = query.select { |r| r["value_coded"] != LINKED_CONCEPT }.map { |r| r["person_id"] }
       
end
      end
    end
  end
end
