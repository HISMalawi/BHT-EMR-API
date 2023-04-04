# frozen_string_literal: true

module HtsService
  module Reports
    module Moh
      # HTS Initial tested for hiv
      class HtsInitialTestedForHiv
        include HtsService::Reports::HtsReportBuilder
        attr_accessor :start_date, :end_date

        def initialize(start_date:, end_date:)
          @start_date = start_date.to_date.beginning_of_day
          @end_date = end_date.to_date.end_of_day
          @data = {
            "total_clients_tested_for_hiv" =>[],
            "total_clients_tested_at_the_facility" => [],
            "facility_vct" =>[],
            "facility_anc_first_visit" => [],
            "facility_inpatient" => [],
            "facility_sti" =>[],
            "facility_pmtct_fup" =>[],
            "facility_index" =>[],
            "facility_paediatric" =>[],
            "facility_vmmc" => [],
            "facility_malnutrition" =>[],
            "facility_tb" => [],
            "facility_opd" => [],
            "facility_other_pitc" =>[],
            "facility_sns" => [],
            "total_clients_tested_in_the_community" => [],
            "community_vmmc" =>[],
            "community_index" =>[],
            "community_mobile" =>[],
            "community_vct" =>[],
            "community_other" => [],
            "community_sns" =>[],
            "access_point_type_invalid_entry" => [],
            "access_point_type_missing" => [],
            "sex_or_pregnancy_total_males" =>[],
            "sex_or_pregnancy_male_circumcised" =>[],
            "sex_or_pregnancy_male_non_circumcised" =>[],
            "sex_or_pregnancy_total_females" =>[],
            "sex_or_pregnancy_female_non_pregnant" => [],
            "sex_or_pregnancy_female_pregnant" =>[],
            "sex_or_pregnancy_female_breastfeeding" => [],
            "sex_or_pregnancy_invalid_entry" => [],
            "sex_or_pregnancy_missing" => [],
            "age_group_years_a_under_1" => [],
            "age_group_years_b_1_to_14" => [],
            "age_group_years_c_15_to_24" => [],
            "age_group_years_d_25_plus" => [],
            "age_group_years_missing" => [],
            "last_hiv_test_never_tested" => [],
            "last_hiv_test_negative_self_test" => [],
            "last_hiv_test_negative_prof_test" => [],
            "last_hiv_test_positive_self_test" => [],
            "last_hiv_test_positive_prof_test" => [],
            "last_hiv_test_invalid_self_test" => [],
            "last_hiv_test_inconclusive_prof_test" => [],
            "last_hiv_test_exposed_infant" => [],
            "last_hiv_test_invalid_entry" => [],
            "last_hiv_test_missing" => [],
            "time_since_last_hiv_test_12_plus_months" => [],
            "time_since_last_hiv_test_6_to_11_months" => [],
            "time_since_last_hiv_test_3_to_5_months" => [],
            "time_since_last_hiv_test_14_days_to_2_months"=> [],
            "time_since_last_hiv_test_1_to_13_days" => [],
            "time_since_last_hiv_test_same_day" => [],
            "time_since_last_hiv_test_invalid_entry" => [],
            "time_since_last_hiv_test_not_applicable_or_missing" => [],
            "ever_taken_arvs_no" => [],
            "ever_taken_arvs_prep" => [],
            "ever_taken_arvs_pep" => [],
            "ever_taken_arvs_art" => [],
            "ever_taken_arvs_invalid_entry" => [],
            "ever_taken_arvs_missing" => [],
            "time_since_last_taken_arvs_12_plus_months" => [],
            "time_since_last_taken_arvs_6_to_11_months" => [],
            "time_since_last_taken_arvs_3_to_5_months" => [],
            "time_since_last_taken_arvs_14_days_to_2_months" => [],
            "time_since_last_taken_arvs_1_to_13_days" => [],
            "time_since_last_taken_arvs_same_day" => [],
            "time_since_last_taken_arvs_invalid_entry" => [],
            "time_since_last_taken_arvs_not_applicable_or_missing" => [],
            "risk_category_low" => [],
            "risk_category_ongoing" => [],
            "risk_category_highrisk_event" => [],
            "risk_category_not_done" => [],
            "risk_category_invalid_entry" => [],
            "risk_category_missing" => [],
            "hiv_test_1_result_negative" => [],
            "hiv_test_1_result_positive" => [],
            "hiv_test_1_result_not_done" => [],
            "hiv_test_1_result_invalid_entry" => [],
            "hiv_test_1_result_missing" => [],
            "hepatitis_b_test_result_negative" => [],
            "hepatitis_b_test_result_positive" => [],
            "hepatitis_b_test_result_not_done" => [],
            "hepatitis_b_test_result_invalid_entry" => [],
            "hepatitis_b_test_result_missing" => [],
            "syphilis_test_result_negative" => [],
            "syphilis_test_result_positive" => [],
            "syphilis_test_result_not_done" => [],
            "syphilis_test_result_invalid_entry" => [],
            "syphilis_test_result_missing" => [],
            "partner_present_yes" => [],
            "partner_present_no" => [],
            "partner_present_invalid_entry" => [],
            "partner_present_missing" => [],
            "partner_hiv_status_no_partner" => [],
            "partner_hiv_status_hiv_status_unknown" => [],
            "partner_hiv_status_hiv_negative" => [],
            "partner_hiv_status_hiv_positive_art_unknown" => [],
            "partner_hiv_status_hiv_positive_not_on_art" => [],
            "partner_hiv_status_hiv_positive_on_art" => [],
            "partner_hiv_status_invalid_entry" => [],
            "partner_hiv_status_missing" => [],
            'referral_for_hiv_retesting_no_retest_needed' => [],
            'referral_for_hiv_retesting_retest_needed' => [],
            'referral_for_hiv_retesting_confirmatory_test' => [],
            'referral_for_hiv_retesting_invalid_entry' => [],
            'referral_for_hiv_retesting_missing' => [],
            'referral_for_prep' => [],
            'referral_for_pep' => [],
            'referral_for_vmmc' => [],
            'referral_for_sti' => [],
            'referral_for_tb' => [],
            'referral_invalid_entry' => [],
            'referral_missing' => [],
            'frs_given_family_referral_slips_sum' => [],
            'frs_given_invalid_entry' => [],
            'male_condoms_given_male_condoms_sum' => [],
            'male_condoms_given_invalid_entry' => [],
            'female_condoms_given_female_condoms_sum' => [],
            'female_condoms_given_invalid_entry' => [],
            'linking_with_hiv_confirmatory_register_total_clients_hiv_test_1_positive' => [],
            'linking_with_hiv_confirmatory_register_linked' => [],
            'missing_link_id_not_in_conf_register' => [],
            'total_clients_hiv_test_1_negative' => [],
            'not_applicable_not_linked' => [],
            'invalid_link_id_in_conf_register' => []
        }
        end

        def data
          report = init_report
          response = @data
        end

        private

        def init_report
          fetch_confirmatory_clients
          fetch_hiv_tests
          fetch_medication
          fetch_partner_status
          fetch_referral_retest
          fetch_male_circumcision
          fetch_pregnancy_test
          fetch_referrals
          fetch_frm_referal
          linked_clients
          set_unique

        end
        def set_unique

          @data.each do |key, array|
              next if array.class != Array
              @data[key]  =  array.uniq
          end

        end


        def fetch_confirmatory_clients

          Person.joins("INNER JOIN encounter e ON e.patient_id = person.person_id AND e.encounter_type = #{EncounterType.find_by_name("TESTING").encounter_type_id} AND e.voided = 0 AND e.program_id = #{Program.find_by_name("HTC Program").program_id}")
                .joins("INNER JOIN obs o1 ON o1.person_id = e.patient_id AND o1.voided = 0 AND o1.concept_id = #{ConceptName.find_by_name('HTS Access Type').concept_id} AND e.encounter_id = o1.encounter_id")
                .joins("INNER JOIN obs o2 ON o2.person_id = e.patient_id AND o2.voided = 0 AND o2.concept_id = #{ConceptName.find_by_name('Location where test took place').concept_id} AND e.encounter_id = o2.encounter_id")
                .joins("INNER JOIN obs o3 ON o3.person_id = e.patient_id AND o3.voided = 0 AND o3.concept_id = #{ConceptName.find_by_name('HIV status').concept_id}")
                .select("person.person_id person_id,person.gender gender,person.birthdate dob,o1.value_coded concept_id,o2.value_text value,o2.encounter_id encounter_id")
                .where("person.voided = 0 AND DATE(e.encounter_datetime) BETWEEN '#{start_date}' AND '#{end_date}' + INTERVAL 1 DAY")
                .each do |client|


                    @data['total_clients_tested_for_hiv'].push(client.person_id)
                    date  = (Date.today.strftime('%Y%m%d').to_i - client.dob.strftime('%Y%m%d').to_i) / 10000
                    @data['age_group_years_a_under_1'].push(client.person_id) if date < 1
                    @data['age_group_years_b_1_to_14'].push(client.person_id) if date > 0 && date < 15
                    @data['age_group_years_c_15_to_24'].push(client.person_id) if date > 14 && date < 25
                    @data['age_group_years_d_25_plus'].push(client.person_id) if date > 24
                    @data['total_clients_tested_at_the_facility'].push(client.person_id) if ConceptName.find_by_name('Health facility').concept_id == client.concept_id
                    @data['total_clients_tested_in_the_community'].push(client.person_id) if ConceptName.find_by_name('Community').concept_id == client.concept_id
                    @data['facility_vct'].push(client.person_id) if client.value == "VCT" && ConceptName.find_by_name('Health facility').concept_id == client.concept_id
                    @data['facility_anc_first_visit'].push(client.person_id) if client.value == "ANC First Visit" && ConceptName.find_by_name('Health facility').concept_id == client.concept_id
                    @data['facility_inpatient'].push(client.person_id) if client.value == "Inpatient" && ConceptName.find_by_name('Health facility').concept_id == client.concept_id
                    @data['facility_sti'].push(client.person_id) if client.value == "STI" && ConceptName.find_by_name('Health facility').concept_id == client.concept_id
                    @data['facility_pmtct_fup'].push(client.person_id) if client.value == "PMTCT FUP" && ConceptName.find_by_name('Health facility').concept_id == client.concept_id
                    @data['facility_index'].push(client.person_id) if client.value == "Index" && ConceptName.find_by_name('Health facility').concept_id == client.concept_id
                    @data['facility_paediatric'].push(client.person_id) if client.value == "Paediatric" && ConceptName.find_by_name('Health facility').concept_id == client.concept_id
                    @data['facility_malnutrition'].push(client.person_id) if client.value == "Malnutrition" && ConceptName.find_by_name('Health facility').concept_id == client.concept_id
                    @data['facility_vmmc'].push(client.person_id) if client.value == "VMMC" && ConceptName.find_by_name('Health facility').concept_id == client.concept_id
                    @data['facility_tb'].push(client.person_id) if client.value == "TB" && ConceptName.find_by_name('Health facility').concept_id == client.concept_id
                    @data['facility_opd'].push(client.person_id) if client.value == "OPD" && ConceptName.find_by_name('Health facility').concept_id == client.concept_id
                    @data['facility_other_pitc'].push(client.person_id) if client.value == "Other PITC" && ConceptName.find_by_name('Health facility').concept_id == client.concept_id
                    @data['facility_sns'].push(client.person_id) if client.value == "SNS" && ConceptName.find_by_name('Health facility').concept_id == client.concept_id
                    @data['community_vmmc'].push(client.person_id) if client.value == "VMMC" && ConceptName.find_by_name('Community').concept_id == client.concept_id
                    @data['community_index'].push(client.person_id) if client.value == "Index" && ConceptName.find_by_name('Community').concept_id == client.concept_id
                    @data['community_mobile'].push(client.person_id) if client.value == "Mobile" && ConceptName.find_by_name('Community').concept_id == client.concept_id
                    @data['community_vct'].push(client.person_id) if client.value == "VCT" && ConceptName.find_by_name('Community').concept_id == client.concept_id
                    @data['community_other'].push(client.person_id) if client.value == "Other" && ConceptName.find_by_name('Community').concept_id == client.concept_id
                    @data['community_sns'].push(client.person_id) if client.value == "SNS" && ConceptName.find_by_name('Community').concept_id == client.concept_id

                       Observation.where(encounter_id:client.encounter_id).each do |tests|

                                  if ConceptName.find_by_name("Test 1").concept_id == tests.concept_id

                                      @data["hiv_test_1_result_negative"].push(client.person_id) if ConceptName.find_by_name('Negative').concept_id == tests.value_coded
                                      @data["total_clients_hiv_test_1_negative"].push(client.person_id) if ConceptName.find_by_name('Negative').concept_id == tests.value_coded
                                      @data["hiv_test_1_result_positive"].push(client.person_id) if ConceptName.find_by_name('Positive').concept_id == tests.value_coded
                                      @data["linking_with_hiv_confirmatory_register_total_clients_hiv_test_1_positive"].push(client.person_id) if ConceptName.find_by_name('Positive').concept_id == tests.value_coded
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



        def fetch_pregnancy_test

          Person.joins("INNER JOIN encounter e ON e.patient_id = person.person_id AND e.encounter_type = #{EncounterType.find_by_name("PREGNANCY STATUS").encounter_type_id} AND e.voided = 0 AND e.program_id = #{Program.find_by_name("HTC Program").program_id}")
                .joins("INNER JOIN obs ON obs.person_id = e.patient_id AND obs.voided = 0 AND obs.concept_id = #{ConceptName.find_by_name('Pregnancy status').concept_id} AND e.encounter_id = obs.encounter_id")
                .select("person.person_id person_id,person.gender gender,obs.value_coded concept_id")
                .where("person.voided = 0 AND DATE(e.encounter_datetime) BETWEEN '#{start_date}' AND '#{end_date}' + INTERVAL 1 DAY")
                .each do |client|
                     @data['sex_or_pregnancy_total_females'].push(client.person_id)
                     @data['sex_or_pregnancy_female_pregnant'].push(client.person_id) if concept('Patient pregnant').concept_id == client.concept_id
                     @data['sex_or_pregnancy_female_non_pregnant'].push(client.person_id) if concept('Not Pregnant / Breastfeeding').concept_id == client.concept_id
                     @data['sex_or_pregnancy_female_breastfeeding'].push(client.person_id) if concept('Breastfeeding').concept_id == client.concept_id

              end
        end
        def fetch_male_circumcision

          Person.joins("INNER JOIN encounter e ON e.patient_id = person.person_id AND e.encounter_type = #{EncounterType.find_by_name("CIRCUMCISION").encounter_type_id} AND e.voided = 0 AND e.program_id = #{Program.find_by_name("HTC Program").program_id}")
                .joins("INNER JOIN obs ON obs.person_id = e.patient_id AND obs.voided = 0 AND obs.concept_id = #{ConceptName.find_by_name('Circumcision status').concept_id} AND e.encounter_id = obs.encounter_id")
                .select("person.person_id person_id,person.gender gender,obs.value_coded concept_id")
                .where("person.voided = 0 AND DATE(e.encounter_datetime) BETWEEN '#{start_date}' AND '#{end_date}' + INTERVAL 1 DAY")
                .each do |client|
                     @data['sex_or_pregnancy_total_males'].push(client.person_id)
                     @data['sex_or_pregnancy_male_circumcised'].push(client.person_id) if ConceptName.find_by_name('Yes').concept_id == client.concept_id
                     @data['sex_or_pregnancy_male_non_circumcised'].push(client.person_id) if ConceptName.find_by_name('No').concept_id == client.concept_id

              end
        end
        def fetch_frm_referal
          query =
          Patient.connection.select_all(his_patients_rev
            .joins(<<-SQL)
              LEFT join obs frs on frs.voided = 0
              AND frs.person_id = person.person_id
              AND frs.concept_id = #{ConceptName.find_by_name('HTS Referal Slips Recipients').concept_id}
              LEFT JOIN obs male_condoms on male_condoms.voided = 0
              AND male_condoms.person_id = person.person_id
              AND male_condoms.concept_id = #{ConceptName.find_by_name('Male condoms').concept_id}
              LEFT JOIN obs female_condoms on female_condoms.voided = 0
              AND female_condoms.person_id = person.person_id
              AND female_condoms.concept_id = #{concept('Female condoms').concept_id}
              SQL
              .select('patient.patient_id, female_condoms.value_numeric as female_condoms, male_condoms.value_numeric as male_condoms, frs.value_numeric as frs').group('patient.patient_id').to_sql
            ).to_hash

              @data['frs_given_family_referral_slips_sum'] = query.map{|q| q['frs'].to_i}.sum
              @data['male_condoms_given_male_condoms_sum'] = query.map{|q| q['male_condoms'].to_i}.sum
              @data['female_condoms_given_female_condoms_sum'] = query.map{|q| q['female_condoms'].to_i}.sum
        end
        def fetch_referral_retest

          Person.joins("INNER JOIN encounter e ON e.patient_id = person.person_id AND e.encounter_type = #{EncounterType.find_by_name("APPOINTMENT").encounter_type_id} AND e.voided = 0 AND e.program_id = #{Program.find_by_name("HTC Program").program_id}")
                .joins("INNER JOIN obs ON obs.person_id = e.patient_id AND obs.voided = 0 AND obs.concept_id = #{ConceptName.find_by_name('Referral for Re-Testing').concept_id} AND e.encounter_id = obs.encounter_id")
                .select("person.person_id person_id,person.gender gender,obs.value_text value")
                .where("person.voided = 0 AND DATE(e.encounter_datetime) BETWEEN '#{start_date}' AND '#{end_date}' + INTERVAL 1 DAY")
                .each do |client|

                     @data['referral_for_hiv_retesting_no_retest_needed'].push(client.person_id) if client.value == 'None'
                     @data['referral_for_hiv_retesting_retest_needed'].push(client.person_id) if client.value == 'Re-Test'
                     @data['referral_for_hiv_retesting_confirmatory_test'].push(client.person_id) if client.value == 'Confirmatory Test'
                    #  @data['referral_for_hiv_retesting_invalid_entry'].push(client.person_id) if client.value == nil
                    #  @data['referral_for_hiv_retesting_missing'].push(client.person_id) if client.value == nil

              end
        end

        def fetch_hiv_tests

          Person.joins("INNER JOIN encounter e ON e.patient_id = person.person_id AND e.encounter_type = #{EncounterType.find_by_name("TESTING").encounter_type_id} AND e.voided = 0 AND e.program_id = #{Program.find_by_name("HTC Program").program_id}")
                .joins("INNER JOIN obs o1 ON o1.person_id = e.patient_id AND o1.voided = 0 AND o1.concept_id = #{ConceptName.find_by_name('Time of HIV test').concept_id} AND e.encounter_id = o1.encounter_id")
                .joins("INNER JOIN obs o2 ON o2.person_id = e.patient_id AND o2.voided = 0 AND o2.concept_id = #{ConceptName.find_by_name('Previous HIV Test Results').concept_id} AND e.encounter_id = o2.encounter_id")
                .joins("INNER JOIN obs o3 ON o3.person_id = e.patient_id AND o3.voided = 0 AND o3.concept_id = #{ConceptName.find_by_name('Previous HIV Test done').concept_id} AND e.encounter_id = o3.encounter_id")
                .select("person.person_id person_id,person.gender gender,o1.obs_datetime obs_date,o1.value_datetime as value,o2.value_coded concept_id,o3.value_coded o3concept_id")
                .where("person.voided = 0 AND DATE(e.encounter_datetime) BETWEEN '#{start_date}' AND '#{end_date}' + INTERVAL 1 DAY")
                .each do |client|
                  next if client.value == nil || client.obs_date == nil
                  @data['last_hiv_test_never_tested'].push(client.person_id) if ConceptName.find_by_name('Never Tested').concept_id == client.concept_id
                  @data['last_hiv_test_negative_self_test'].push(client.person_id) if ConceptName.find_by_name('Self').concept_id == client.o3concept_id && ConceptName.find_by_name('Negative').concept_id == client.concept_id
                  @data["last_hiv_test_negative_prof_test"].push(client.person_id) if ConceptName.find_by_name('Professional').concept_id == client.o3concept_id && ConceptName.find_by_name('Negative').concept_id == client.concept_id
                  @data["last_hiv_test_positive_self_test"].push(client.person_id) if ConceptName.find_by_name('Self').concept_id == client.o3concept_id && ConceptName.find_by_name('Positive').concept_id == client.concept_id
                  @data["last_hiv_test_positive_prof_test"].push(client.person_id) if ConceptName.find_by_name('Professional').concept_id == client.o3concept_id && ConceptName.find_by_name('Positive').concept_id == client.concept_id
                  time_since_last_hiv_result = client.value
                  obs_datetime = client.obs_date
                  diff = (obs_datetime.to_date - time_since_last_hiv_result.to_date).to_i
                  @data["time_since_last_hiv_test_same_day"].push(client.person_id) if time_since_last_hiv_result.to_date == obs_datetime.to_date
                  @data["time_since_last_hiv_test_1_to_13_days"].push(client.person_id) if diff >= 1 && diff <= 13
                  @data["time_since_last_hiv_test_14_days_to_2_months"].push(client.person_id) if diff >= 14 && diff <= 60
                  @data["time_since_last_hiv_test_3_to_5_months"].push(client.person_id) if diff >= 61 && diff <= 150
                  @data["time_since_last_hiv_test_6_to_11_months"].push(client.person_id) if diff >= 151 && diff <= 330
                  @data["time_since_last_hiv_test_12_plus_months"].push(client.person_id) if diff >= 331
                end
        end
        def fetch_medication

          Person.joins("INNER JOIN encounter e ON e.patient_id = person.person_id AND e.encounter_type = #{EncounterType.find_by_name("TESTING").encounter_type_id} AND e.voided = 0 AND e.program_id = #{Program.find_by_name("HTC Program").program_id}")
                .joins("INNER JOIN obs o1 ON o1.person_id = e.patient_id AND o1.voided = 0 AND o1.concept_id = #{ConceptName.find_by_name('Antiretroviral medication history').concept_id} AND e.encounter_id = o1.encounter_id")
                .select("person.person_id person_id,person.gender gender,o1.value_coded concept_id,o1.encounter_id encounterid")
                .where("person.voided = 0 AND DATE(e.encounter_datetime) BETWEEN '#{start_date}' AND '#{end_date}' + INTERVAL 1 DAY")
                .group("person.person_id")
                .each do |client|
                    @data["ever_taken_arvs_no"].push(client.person_id) if ConceptName.find_by_name('No').concept_id == client.concept_id
                    if ConceptName.find_by_name('Yes').concept_id == client.concept_id

                            Observation.where(encounter_id:client.encounterid,
                                                 person_id: client.person_id).each do |drug|

                                  if ConceptName.find_by_name("Given drugs").concept_id == drug.concept_id

                                       @data["ever_taken_arvs_prep"].push(client.person_id) if concept('Prep or infant NVP').concept_id == drug.value_coded
                                       @data["ever_taken_arvs_pep"].push(client.person_id) if concept('PEP').concept_id == drug.value_coded
                                       @data["ever_taken_arvs_art"].push(client.person_id) if concept('ART').concept_id == drug.value_coded

                                  end
                                  if ConceptName.find_by_name("Time since last taken medication").concept_id == drug.concept_id
                                    time_since_last_hiv_result = drug.value_datetime
                                    obs_datetime = drug.obs_datetime
                                    diff = (obs_datetime.to_date - time_since_last_hiv_result.to_date).to_i
                                    @data["time_since_last_taken_arvs_same_day"].push(drug.person_id) if time_since_last_hiv_result.to_date == obs_datetime.to_date
                                    @data["time_since_last_taken_arvs_1_to_13_days"].push(drug.person_id) if diff >= 1 && diff <= 13
                                    @data["time_since_last_taken_arvs_14_days_to_2_months"].push(drug.person_id) if diff >= 14 && diff <= 60
                                    @data["time_since_last_taken_arvs_3_to_5_months"].push(drug.person_id) if diff >= 61 && diff <= 150
                                    @data["time_since_last_taken_arvs_6_to_11_months"].push(drug.person_id) if diff >= 151 && diff <= 330
                                    @data["time_since_last_taken_arvs_12_plus_months"].push(drug.person_id) if diff >= 331
                                  end
                                  if ConceptName.find_by_name("client risk category").concept_id == drug.concept_id

                                           @data["risk_category_low"].push(client.person_id) if ConceptName.find_by_name('Low risk').concept_id == drug.value_coded
                                           @data["risk_category_ongoing"].push(client.person_id) if ConceptName.find_by_name('On-going risk').concept_id == drug.value_coded
                                           @data["risk_category_highrisk_event"].push(client.person_id) if ConceptName.find_by_name('High risk event in last 3 months').concept_id == drug.value_coded
                                           @data["risk_category_not_done"].push(client.person_id) if ConceptName.find_by_name('Risk assessment not done').concept_id == drug.value_coded

                                  end

                            end
                      end
                end


        end

        def fetch_partner_status

          Person.joins("INNER JOIN encounter e ON e.patient_id = person.person_id AND e.encounter_type = #{EncounterType.find_by_name("Partner Reception").encounter_type_id} AND e.voided = 0 AND e.program_id = #{Program.find_by_name("HTC Program").program_id}")
                .joins("INNER JOIN obs ON obs.person_id = e.patient_id AND obs.voided = 0 AND obs.concept_id = #{ConceptName.find_by_name('Partner Present').concept_id} AND e.encounter_id = obs.encounter_id")
                .select("person.person_id person_id,person.gender gender,obs.value_text value,obs.encounter_id encounter_id")
                .where("person.voided = 0 AND DATE(e.encounter_datetime) BETWEEN '#{start_date}' AND '#{end_date}' + INTERVAL 1 DAY")
                .group("person.person_id")
                .each do |client|

                     @data['partner_present_yes'].push(client.person_id) if client.value == "Yes"
                     @data["partner_present_no"].push(client.person_id) if client.value == "No"

                    partner_status = Observation.where(encounter_id:client.encounter_id,
                                         person_id:client.person_id,
                                        concept_id:"#{ConceptName.find_by_name("Partner HIV Status").concept_id}").last

                    @data["partner_hiv_status_no_partner"].push(partner_status.person_id) if partner_status.value_coded == concept("No partner").concept_id
                    @data["partner_hiv_status_hiv_status_unknown"].push(partner_status.person_id) if ConceptName.find_by_name('HIV unknown').concept_id == partner_status.value_coded
                    @data["partner_hiv_status_hiv_negative"].push(partner_status.person_id) if ConceptName.find_by_name('Negative').concept_id == partner_status.value_coded
                    @data["partner_hiv_status_hiv_positive_art_unknown"].push(partner_status.person_id) if ConceptName.find_by_name('Positive Art unknown').concept_id == partner_status.value_coded
                    @data["partner_hiv_status_hiv_positive_not_on_art"].push(partner_status.person_id) if ConceptName.find_by_name('Positive NOT on ART').concept_id == partner_status.value_coded
                    @data["partner_hiv_status_hiv_positive_on_art"].push(partner_status.person_id) if ConceptName.find_by_name('Positive on ART').concept_id == partner_status.value_coded
              end
        end

        def fetch_referrals

          Person.joins("INNER JOIN encounter e ON e.patient_id = person.person_id AND e.encounter_type = #{EncounterType.find_by_name("TESTING").encounter_type_id} AND e.voided = 0 AND e.program_id = #{Program.find_by_name("HTC Program").program_id}")
                .joins("INNER JOIN obs o1 ON o1.person_id = e.patient_id AND o1.voided = 0 AND o1.concept_id = #{ConceptName.find_by_name('HIV status').concept_id} AND o1.value_coded = #{ConceptName.find_by_name('Positive').concept_id} AND e.encounter_id = o1.encounter_id")
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

                  @data['referral_for_vmmc'].push(client.person_id) if obs.value == "VMMC"
                  @data['referral_for_prep'].push(client.person_id) if obs.value == 'PrEP'
                  @data['referral_for_sti'].push(client.person_id) if obs.value == 'STI'
                  @data['referral_for_tb'].push(client.person_id) if obs.value == 'TB'
                  @data['referral_for_pep'].push(client.person_id) if obs.value == 'PEP'

              end

             end

       end

       def linked_clients
        query = Patient.connection.select_all(
          his_patients_rev
            .joins(<<-SQL)
              LEFT JOIN obs linked ON linked.person_id = person.person_id
              AND linked.voided = 0
              AND linked.concept_id = #{ART_OUTCOME}
              SQL
          .select("person.person_id, max(linked.value_coded) as value_coded")
          .group("person.person_id").to_sql
        ).to_hash
        @data["linking_with_hiv_confirmatory_register_linked"] = query.select{|r| r["value_coded"] == LINKED_CONCEPT}.map{|r| r["person_id"]}
        @data['not_applicable_not_linked'] = query.select{|r| r["value_coded"] != LINKED_CONCEPT}.map{|r| r["person_id"]}
      end






      end
    end
  end
end
