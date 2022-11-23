# frozen_string_literal: true

module HtsService
  module Reports
    module Moh
      # HTS Initial tested for hiv
      class HtsInitialTestedForHiv
        attr_accessor :start_date, :end_date

        include ARTService::Reports::Pepfar::Utils

        def initialize(start_date:, end_date:)
          @start_date = start_date
          @end_date = end_date
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

           }
        end

        def data
          report = init_report
          response = @data
        end

        private

        def init_report

          #fetch_clients_tested
          #fetch_confirmatory_clients
          #fetch_male_circumcision
          #fetch_pregnancy_test
          #fetch_tests
          #fetch_drugs
          fetch_partner_status

        end


        def fetch_clients_tested


          Person.joins("INNER JOIN encounter e ON e.patient_id = person.person_id AND e.encounter_type = #{EncounterType.find_by_name("TESTING").encounter_type_id} AND e.voided = 0 AND e.program_id = #{Program.find_by_name("HTC Program").program_id}")
                .joins("INNER JOIN obs ON obs.person_id = e.patient_id AND obs.voided = 0 AND obs.concept_id = #{ConceptName.find_by_name('HIV status').concept_id} AND e.encounter_id = obs.encounter_id")
                .select("person.person_id person_id,person.gender gender,person.birthdate dob")
                .where("person.voided = 0 AND DATE(e.encounter_datetime) BETWEEN '#{start_date}' AND '#{end_date}' + INTERVAL 1 DAY")
                .each do |client|

                     @data['total_clients_tested_for_hiv'].push(client.person_id)
                     @data['sex_or_pregnancy_total_males'].push(client.person_id) if client.gender = "M"
                     @data['sex_or_pregnancy_total_females'].push(client.person_id) if client.gender = "F"
                     date  = (Date.today.strftime('%Y%m%d').to_i - client.dob.strftime('%Y%m%d').to_i) / 10000
                     @data['age_group_years_a_under_1'].push(client.person_id) if date < 1
                     @data['age_group_years_b_1_to_14'].push(client.person_id) if date > 0 && date < 15
                     @data['age_group_years_c_15_to_24'].push(client.person_id) if date > 14 && date < 25
                     @data['age_group_years_d_25_plus'].push(client.person_id) if date > 24
              end
        end
        def fetch_pregnancy_test


          Person.joins("INNER JOIN encounter e ON e.patient_id = person.person_id AND e.encounter_type = #{EncounterType.find_by_name("PREGNANCY STATUS").encounter_type_id} AND e.voided = 0 AND e.program_id = #{Program.find_by_name("HTC Program").program_id}")
                .joins("INNER JOIN obs ON obs.person_id = e.patient_id AND obs.voided = 0 AND obs.concept_id = #{ConceptName.find_by_name('Pregnancy status').concept_id} AND e.encounter_id = obs.encounter_id")
                .select("person.person_id person_id,person.gender gender,obs.value_coded concept_id")
                .where("person.voided = 0 AND DATE(e.encounter_datetime) BETWEEN '#{start_date}' AND '#{end_date}' + INTERVAL 1 DAY")
                .each do |client|

                     @data['sex_or_pregnancy_female_pregnant'].push(client.person_id) if ConceptName.find_by_name('Patient pregnant').concept_id == client.concept_id
                     @data['sex_or_pregnancy_female_non_pregnant'].push(client.person_id) if ConceptName.find_by_name('Not Pregnant / Breastfeeding').concept_id == client.concept_id
                     @data['sex_or_pregnancy_female_breastfeeding'].push(client.person_id) if ConceptName.find_by_name('Breastfeeding').concept_id == client.concept_id

              end
        end
        def fetch_male_circumcision

          Person.joins("INNER JOIN encounter e ON e.patient_id = person.person_id AND e.encounter_type = #{EncounterType.find_by_name("CIRCUMCISION").encounter_type_id} AND e.voided = 0 AND e.program_id = #{Program.find_by_name("HTC Program").program_id}")
                .joins("INNER JOIN obs ON obs.person_id = e.patient_id AND obs.voided = 0 AND obs.concept_id = #{ConceptName.find_by_name('Circumcision status').concept_id} AND e.encounter_id = obs.encounter_id")
                .select("person.person_id person_id,person.gender gender,obs.value_coded concept_id")
                .where("person.voided = 0 AND DATE(e.encounter_datetime) BETWEEN '#{start_date}' AND '#{end_date}' + INTERVAL 1 DAY")
                .each do |client|

                     @data['sex_or_pregnancy_male_circumcised'].push(client.person_id) if ConceptName.find_by_name('Yes').concept_id == client.concept_id
                     @data['sex_or_pregnancy_male_non_circumcised'].push(client.person_id) if ConceptName.find_by_name('Yes').concept_id == client.concept_id

              end
        end
        def fetch_tests

          Person.joins("INNER JOIN encounter e ON e.patient_id = person.person_id AND e.encounter_type = #{EncounterType.find_by_name("TESTING").encounter_type_id} AND e.voided = 0 AND e.program_id = #{Program.find_by_name("HTC Program").program_id}")
                .joins("INNER JOIN obs o1 ON o1.person_id = e.patient_id AND o1.voided = 0 AND o1.concept_id = #{ConceptName.find_by_name('Time of HIV test').concept_id} AND e.encounter_id = o1.encounter_id")
                .joins("INNER JOIN obs o2 ON o2.person_id = e.patient_id AND o2.voided = 0 AND o2.concept_id = #{ConceptName.find_by_name('Previous HIV Test Results').concept_id} AND e.encounter_id = o2.encounter_id")
                .joins("INNER JOIN obs o3 ON o3.person_id = e.patient_id AND o3.voided = 0 AND o3.concept_id = #{ConceptName.find_by_name('Previous HIV Test done').concept_id} AND e.encounter_id = o3.encounter_id")
                .select("person.person_id person_id,person.gender gender,o1.value_text value,o2.value_coded concept_id,o3.value_coded o3concept_id")
                .where("person.voided = 0 AND DATE(e.encounter_datetime) BETWEEN '#{start_date}' AND '#{end_date}' + INTERVAL 1 DAY")
                .each do |client|

                  @data['last_hiv_test_never_tested'].push(client.person_id) if ConceptName.find_by_name('Never Tested').concept_id == client.concept_id
                  @data['last_hiv_test_negative_self_test'].push(client.person_id) if ConceptName.find_by_name('Self').concept_id == client.o3concept_id && ConceptName.find_by_name('Negative').concept_id == client.concept_id
                  @data["last_hiv_test_negative_prof_test"].push(client.person_id) if ConceptName.find_by_name('Professional').concept_id == client.o3concept_id && ConceptName.find_by_name('Negative').concept_id == client.concept_id
                  @data["last_hiv_test_positive_self_test"].push(client.person_id) if ConceptName.find_by_name('Self').concept_id == client.o3concept_id && ConceptName.find_by_name('Positive').concept_id == client.concept_id
                  @data["last_hiv_test_positive_prof_test"].push(client.person_id) if ConceptName.find_by_name('Professional').concept_id == client.o3concept_id && ConceptName.find_by_name('Positive').concept_id == client.concept_id

                  array = client.value.to_s.split(" ")
                  case array[1].to_s

                    when "Days"

                    @data["time_since_last_hiv_test_same_day"].push(client.person_id) if array[0].to_i == 1
                    @data["time_since_last_hiv_test_1_to_13_days"].push(client.person_id) if array[0].to_i > 1 && array[0].to_i < 14
                    @data["time_since_last_hiv_test_14_days_to_2_months"].push(client.person_id) if array[0].to_i > 13 && array[0].to_i < 61
                    @data["time_since_last_hiv_test_3_to_5_months"].push(client.person_id) if array[0].to_i > 60 && array[0].to_i < 150
                    @data["time_since_last_hiv_test_6_to_11_months"].push(client.person_id) if array[0].to_i > 149 && array[0].to_i < 330
                    @data["time_since_last_hiv_test_12_plus_months"].push(client.person_id) if array[0].to_i > 329

                    when "Months"

                    @data["time_since_last_hiv_test_14_days_to_2_months"].push(client.person_id) if array[0].to_i < 3
                    @data["time_since_last_hiv_test_3_to_5_months"].push(client.person_id) if array[0].to_i > 2 && array[0].to_i < 6
                    @data["time_since_last_hiv_test_6_to_11_months"].push(client.person_id) if array[0].to_i > 5 && array[0].to_i < 12
                    @data["time_since_last_hiv_test_12_plus_months"].push(client.person_id) if array[0].to_i > 11

                  end

                   #@data["time_since_last_hiv_test_invalid_entry"].push(client.person_id)
                   #@data["time_since_last_hiv_test_not_applicable_or_missing"].push(client.person_id)
                end
        end
        def fetch_drugs

          Person.joins("INNER JOIN encounter e ON e.patient_id = person.person_id AND e.encounter_type = #{EncounterType.find_by_name("TESTING").encounter_type_id} AND e.voided = 0 AND e.program_id = #{Program.find_by_name("HTC Program").program_id}")
                .joins("INNER JOIN obs o1 ON o1.person_id = e.patient_id AND o1.voided = 0 AND o1.concept_id = #{ConceptName.find_by_name('Antiretroviral medication history').concept_id} AND e.encounter_id = o1.encounter_id")
                .select("person.person_id person_id,person.gender gender,o1.value_coded concept_id,o1.encounter_id encounterid")
                .where("person.voided = 0 AND DATE(e.encounter_datetime) BETWEEN '#{start_date}' AND '#{end_date}' + INTERVAL 1 DAY")
                .each do |client|

                    if ConceptName.find_by_name('No').concept_id == client.concept_id

                        @data["ever_taken_arvs_no"].push(client.person_id)

                    elsif ConceptName.find_by_name('Yes').concept_id == client.concept_id

                            Observation.where(encounter_id:client.encounterid).each do |drug|

                                  if ConceptName.find_by_name("Given drugs").concept_id == drug.concept_id

                                       @data["ever_taken_arvs_prep"].push(client.person_id) if ConceptName.find_by_name('Prep or infant NVP').concept_id == drug.value_coded
                                       @data["ever_taken_arvs_pep"].push(client.person_id) if ConceptName.find_by_name('PEP').concept_id == drug.value_coded
                                       @data["ever_taken_arvs_art"].push(client.person_id) if ConceptName.find_by_name('ARV').concept_id == drug.value_coded
                                      #@data["ever_taken_arvs_invalid_entry"].push(client.person_id) if ConceptName.find_by_name('Prep or infant NVP').concept_id == drug.value_coded
                                      #@data["ever_taken_arvs_missing"].push(client.person_id) if ConceptName.find_by_name('Prep or infant NVP').concept_id == drug.value_coded

                                  end
                                  if ConceptName.find_by_name("Time since last taken medication").concept_id == drug.concept_id

                                        array = drug.value_text.to_s.split(" ")
                                       case array[1].to_s

                                            when "Days"

                                                 @data["time_since_last_taken_arvs_same_day"].push(client.person_id) if array[0].to_i == 1
                                                 @data["time_since_last_taken_arvs_1_to_13_days"].push(client.person_id) if array[0].to_i > 1 && array[0].to_i < 14
                                                 @data["time_since_last_taken_arvs_14_days_to_2_months"].push(client.person_id) if array[0].to_i > 13 && array[0].to_i < 61
                                                 @data["time_since_last_taken_arvs_3_to_5_months"].push(client.person_id) if array[0].to_i > 60 && array[0].to_i < 150
                                                 @data["time_since_last_taken_arvs_6_to_11_months"].push(client.person_id) if array[0].to_i > 149 && array[0].to_i < 330
                                                 @data["time_since_last_taken_arvs_12_plus_months"].push(client.person_id) if array[0].to_i > 329

                                            when "Months"

                                                @data["time_since_last_taken_arvs_14_days_to_2_months"].push(client.person_id) if array[0].to_i < 3
                                                @data["time_since_last_taken_arvs_3_to_5_months"].push(client.person_id) if array[0].to_i > 2 && array[0].to_i < 6
                                                @data["time_since_last_taken_arvs_6_to_11_months"].push(client.person_id) if array[0].to_i > 5 && array[0].to_i < 12
                                                @data["time_since_last_taken_arvs_12_plus_months"].push(client.person_id) if array[0].to_i > 11
                                        end

                                             #@data["time_since_last_taken_arvs_invalid_entry"].push(client.person_id)
                                             #@data["time_since_last_taken_arvs_not_applicable_or_missing"].push(client.person_id)
                                  end
                                  if ConceptName.find_by_name("client risk category").concept_id == drug.concept_id

                                           @data["risk_category_low"].push(client.person_id) if ConceptName.find_by_name('Low risk').concept_id == drug.value_coded
                                           @data["risk_category_ongoing"].push(client.person_id) if ConceptName.find_by_name('On-going risk').concept_id == drug.value_coded
                                           @data["risk_category_highrisk_event"].push(client.person_id) if ConceptName.find_by_name('High risk event in last 3 months').concept_id == drug.value_coded
                                           @data["risk_category_not_done"].push(client.person_id) if ConceptName.find_by_name('Risk assessment not done').concept_id == drug.value_coded
                                           #@data["risk_category_invalid_entry"].push(client.person_id) if ConceptName.find_by_name('PEP').concept_id == drug.value_coded
                                           #@data["risk_category_missing"].push(client.person_id) if ConceptName.find_by_name('ARV').concept_id == drug.value_coded

                                  end




                            end



                      end
                end


        end

        def fetch_partner_status


          Person.joins("INNER JOIN encounter e ON e.patient_id = person.person_id AND e.encounter_type = #{EncounterType.find_by_name("Partner Reception").encounter_type_id} AND e.voided = 0 AND e.program_id = #{Program.find_by_name("HTC Program").program_id}")
                .joins("INNER JOIN obs ON obs.person_id = e.patient_id AND obs.voided = 0 AND obs.concept_id = #{ConceptName.find_by_name('Partner Present').concept_id} AND e.encounter_id = obs.encounter_id")
                .select("person.person_id person_id,person.gender gender,obs.value_text value")
                .where("person.voided = 0 AND DATE(e.encounter_datetime) BETWEEN '#{start_date}' AND '#{end_date}' + INTERVAL 1 DAY")
                .each do |client|

                     @data['partner_present_yes'].push(client.person_id) if client.value == "Yes"
                     @data["partner_present_no"].push(client.person_id) if client.value == "No"
                    # @data["partner_present_invalid_entry"].push(client.person_id) if client.value == "Yes"
                    # @data["partner_present_missing"].push(client.person_id) if client.value == "No"


                    #@data["partner_hiv_status_no_partner"].push(client.person_id) if client.value == "Yes"
                    #@data["partner_hiv_status_hiv_status_unknown"].push(client.person_id) if client.value == "No"
                    #@data["partner_hiv_status_hiv_negative"].push(client.person_id) if client.value == "Yes"
                    #@data["partner_hiv_status_hiv_positive_art_unknown"].push(client.person_id) if client.value == "No"
                    #@data["partner_hiv_status_hiv_positive_not_on_art"].push(client.person_id) if client.value == "Yes"
                    #@data["partner_hiv_status_hiv_positive_on_art"].push(client.person_id) if client.value == "No"
                    #@data["partner_hiv_status_invalid_entry"].push(client.person_id) if client.value == "Yes"
                   # @data["partner_hiv_status_missing"].push(client.person_id) if client.value == "No"

              end
        end
        def fetch_confirmatory_clients

          Person.joins("INNER JOIN encounter e ON e.patient_id = person.person_id AND e.encounter_type = #{EncounterType.find_by_name("TESTING").encounter_type_id} AND e.voided = 0 AND e.program_id = #{Program.find_by_name("HTC Program").program_id}")
                .joins("INNER JOIN obs o1 ON o1.person_id = e.patient_id AND o1.voided = 0 AND o1.concept_id = #{ConceptName.find_by_name('HTS Access Type').concept_id} AND e.encounter_id = o1.encounter_id")
                .joins("INNER JOIN obs o2 ON o2.person_id = e.patient_id AND o2.voided = 0 AND o2.concept_id = #{ConceptName.find_by_name('Location where test took place').concept_id} AND e.encounter_id = o2.encounter_id")
                .select("person.person_id person_id,o1.value_coded concept_id,o2.value_text value,o2.encounter_id encounter_id")
                .where("person.voided = 0 AND DATE(e.encounter_datetime) BETWEEN '#{start_date}' AND '#{end_date}' + INTERVAL 1 DAY")
                .each do |client|

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
                                            @data["hiv_test_1_result_positive"].push(client.person_id) if ConceptName.find_by_name('Positive').concept_id == tests.value_coded
                                           #@data["hiv_test_1_result_not_done"].push(client.person_id) if ConceptName.find_by_name('High risk event in last 3 months').concept_id == drug.value_coded
                                            #@data["hiv_test_1_result_invalid_entry"].push(client.person_id) if ConceptName.find_by_name('Risk assessment not done').concept_id == drug.value_coded
                                            #@data["hiv_test_1_result_missing"].push(client.person_id) if ConceptName.find_by_name('Risk assessment not done').concept_id == drug.value_coded
                                    end

                                   if ConceptName.find_by_name('Hepatitis B Test Result').concept_id == tests.concept_id

                                     @data["hepatitis_b_test_result_negative"].push(client.person_id) if ConceptName.find_by_name('Negative').concept_id == tests.value_coded
                                     @data["hepatitis_b_test_result_positive"].push(client.person_id) if ConceptName.find_by_name('Positive').concept_id == tests.value_coded
                                    #@data["hepatitis_b_test_result_not_done"].push(client.person_id) if ConceptName.find_by_name('High risk event in last 3 months').concept_id == drug.value_coded
                                    #@data["hepatitis_b_test_result_invalid_entry"].push(client.person_id) if ConceptName.find_by_name('Risk assessment not done').concept_id == drug.value_coded
                                    #@data["hepatitis_b_test_result_missing"].push(client.person_id) if ConceptName.find_by_name('Risk assessment not done').concept_id == drug.value_coded

                                   end

                                   if ConceptName.find_by_name('Syphilis Test Result').concept_id == tests.concept_id

                                    @data["syphilis_test_result_negative"].push(client.person_id) if ConceptName.find_by_name('Negative').concept_id == tests.value_coded
                                    @data["syphilis_test_result_positive"].push(client.person_id) if ConceptName.find_by_name('Positive').concept_id == tests.value_coded
                                   #@data["syphilis_test_result_not_done"].push(client.person_id) if ConceptName.find_by_name('High risk event in last 3 months').concept_id == drug.value_coded
                                   #@data["syphilis_test_result_invalid_entry"].push(client.person_id) if ConceptName.find_by_name('Risk assessment not done').concept_id == drug.value_coded
                                   #@data["syphilis_test_result_missing"].push(client.person_id) if ConceptName.find_by_name('Risk assessment not done').concept_id == drug.value_coded

                                  end
                    end

                end
        end




      end
    end
  end
end
