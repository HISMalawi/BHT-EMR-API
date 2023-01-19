# frozen_string_literal: true

module HtsService
  module Reports
    module Moh
      # HTS Initial tested for hiv
      class HtsConfirmatory
        attr_accessor :start_date, :end_date

        def initialize(start_date:, end_date:)
          @start_date = start_date
          @end_date = end_date
          @data = {
'total_clients_in_confirmatory_register' => [],
'hiv_test_2_result_negative' => [],
'hiv_test_2_result_positive' => [],
'hiv_test_2_result_invalid_entry' => [],
'hiv_test_2_result_missing' => [],
'hiv_test_3_result_negative' => [],
'hiv_test_3_result_positive' => [],
'hiv_test_3_result_invalid_entry' => [],
'hiv_test_3_result_not_applicable_or_missing' => [],
'hiv_test_1_repeat_result_negative' =>[],
'hiv_test_1_repeat_result_positive' => [],
'hiv_test_1_repeat_result_invalid_entry' => [],
'hiv_test_1_repeat_result_not_applicable_or_missing' => [],
'result_given_to_client_negative' => [],
'result_given_to_client_positive' => [],
'result_given_to_client_inconclusive' => [],
'result_given_to_client_exposed_infant' => [],
'result_given_to_client_invalid_entry' => [],
'result_given_to_client_missing' => [],
'rtri_result_longterm' => [],
'rtri_result_recent' => [],
'rtri_result_negative' => [],
'invalid_rtri_result' => [],
'rtri_result_not_done' => [],
'rtri_result_invalid_entry' => [],
'rtri_result_missing_among_hiv_positive_clients' => [],
'rtri_result_not_applicable' => [],
'dbs_collected_no' => [],
'dbs_collected_yes' => [],
'dbs_collected_invalid_entry' => [],
'dbs_collected_missing_where_rtri_recent' => [],
'dbs_collected_not_applicable' => [],
'specimen_ids_valid_ids_entered' => [],
'specimen_ids_invalid_entry' => [],
'specimen_ids_missing_where_dbs_collected' => [],
'specimen_ids_not_applicable' => [],
'referral_for_retesting_after_confirmatory_no' => [],
'referral_for_retesting_after_confirmatory_yes' => [],
'referral_for_retesting_after_confirmatory_invalid_entry' => [],
'referral_for_retesting_after_confirmatory_missing' => [],
'referral_for_art_initiation_no' => [],
'referral_for_art_initiation_yes' => [],
'referral_for_art_initiation_invalid_entry' => [],
'referral_for_art_initiation_missing' => [],
'art_referral_outcome_linked' => [],
'art_referral_outcome_refused' => [],
'art_referral_outcome_died' => [],
'art_referral_outcome_unknown' => [],
'art_referral_outcome_invalid_entry' => [],
'art_referral_outcome_missing_where_referred_for_art' => [],
'art_referral_outcome_not_applicable' => [],
'art_clinic_registration_indexber_valid_entry' => [],
'art_clinic_registration_indexber_invalid_entry' => [],
'art_clinic_registration_indexber_missing_among_clients_linked_to_art' => [],
'art_clinic_registration_indexber_not_applicable' => [],
'linking_with_initial_register_valid_linkid' => [],
'linking_with_initial_register_invalid_linkid' => [],
'linking_with_initial_register_missing_linkid' => []

}
        end

        def data
          report = init_report
          response = @data
        end

        private

        def init_report

          fetch_confirmatory_register
          fetch_retest_referral
          fetch_art_referral
          fetch_art_referral_outcome
          set_unique

        end
        def set_unique

          @data.each do |key, array|    
              @data[key]  =  array.uniq
          end

        end        


        def fetch_confirmatory_register

          Person.joins("INNER JOIN encounter e ON e.patient_id = person.person_id AND e.encounter_type = #{EncounterType.find_by_name("TESTING").encounter_type_id} AND e.voided = 0 AND e.program_id = #{Program.find_by_name("HTC Program").program_id}")
                .joins("INNER JOIN obs ON obs.person_id = e.patient_id AND obs.voided = 0 AND obs.concept_id = #{ConceptName.find_by_name('HIV test type').concept_id} AND e.encounter_id = obs.encounter_id")
                .select("person.person_id person_id,obs.encounter_id encounter_id")
                .where(obs:{value_coded: ConceptName.find_by_name('Confirmatory HIV test').concept_id})
                .where("person.voided = 0 AND DATE(e.encounter_datetime) BETWEEN '#{start_date}' AND '#{end_date}' + INTERVAL 1 DAY")
                .each do |client|                    

                    @data['total_clients_in_confirmatory_register'].push(client.person_id)                     

                     Observation.where(encounter_id:client.encounter_id,
                                             person: client.person_id).each do |tests|

                         if ConceptName.find_by_name('Test 2').concept_id == tests.concept_id

                           @data["hiv_test_2_result_negative"].push(client.person_id) if ConceptName.find_by_name('Negative').concept_id == tests.value_coded
                           @data["hiv_test_2_result_positive"].push(client.person_id) if ConceptName.find_by_name('Positive').concept_id == tests.value_coded
                           @data["hiv_test_2_result_invalid_entry"].push(client.person_id) if tests.value_coded == nil
                           @data["hiv_test_2_result_missing"].push(client.person_id) if tests.value_coded == nil

                          elsif ConceptName.find_by_name('Test 3').concept_id == tests.concept_id

                           @data["hiv_test_3_result_negative"].push(client.person_id) if ConceptName.find_by_name('Negative').concept_id == tests.value_coded
                           @data["hiv_test_3_result_positive"].push(client.person_id) if ConceptName.find_by_name('Positive').concept_id == tests.value_coded
                           @data["hiv_test_3_result_invalid_entry"].push(client.person_id) if tests.value_coded == nil
                           @data["hiv_test_3_result_not_applicable_or_missing"].push(client.person_id) if tests.value_coded == nil

                          elsif ConceptName.find_by_name('Immediate Repeat Test 1 Result').concept_id == tests.concept_id

                            @data["hiv_test_1_repeat_result_negative"].push(client.person_id) if ConceptName.find_by_name('Negative').concept_id == tests.value_coded
                            @data["hiv_test_1_repeat_result_positive"].push(client.person_id) if ConceptName.find_by_name('Positive').concept_id == tests.value_coded
                            @data["hiv_test_1_repeat_result_invalid_entry"].push(client.person_id) if tests.value_coded == nil
                            @data["hiv_test_1_repeat_result_not_applicable_or_missing"].push(client.person_id) if tests.value_coded == nil

                          elsif ConceptName.find_by_name('HIV status').concept_id == tests.concept_id

                            @data["result_given_to_client_negative"].push(client.person_id) if ConceptName.find_by_name('Negative').concept_id == tests.value_coded
                            @data["result_given_to_client_positive"].push(client.person_id) if ConceptName.find_by_name('Positive').concept_id == tests.value_coded
                            #@data["result_given_to_client_inconclusive"].push(client.person_id) if ConceptName.find_by_name('Inconclusive').concept_id == tests.value_coded
                            @data["result_given_to_client_exposed_infant"].push(client.person_id) if ConceptName.find_by_name('Exposed Infant').concept_id == tests.value_coded
                            @data["result_given_to_client_invalid_entry"].push(client.person_id) if tests.value_coded == nil
                            @data["result_given_to_client_missing"].push(client.person_id) if tests.value_coded == nil

                          elsif ConceptName.find_by_name('Recency Test').concept_id == tests.concept_id

                            @data["rtri_result_longterm"].push(client.person_id) if ConceptName.find_by_name('Long-Term').concept_id == tests.value_coded
                            @data["rtri_result_recent"].push(client.person_id) if ConceptName.find_by_name('Recent').concept_id == tests.value_coded
                            #@data["rtri_result_negative"].push(client.person_id) if ConceptName.find_by_name('Not Done').concept_id == tests.value_coded
                            @data["rtri_result_not_done"].push(client.person_id) if ConceptName.find_by_name('Not Done').concept_id == tests.value_coded
                            @data["rtri_result_invalid_entry"].push(client.person_id) if ConceptName.find_by_name('Invalid').concept_id == tests.value_coded
                            @data["rtri_result_missing_among_hiv_positive_clients"].push(client.person_id) if tests.value_coded == nil
                            @data["rtri_result_not_applicable"].push(client.person_id) if tests.value_coded == nil


                          elsif ConceptName.find_by_name('Is DBS Sample Collected').concept_id == tests.concept_id

                            @data["dbs_collected_no"].push(client.person_id) if ConceptName.find_by_name('No').concept_id == tests.value_coded
                            @data["dbs_collected_yes"].push(client.person_id) if ConceptName.find_by_name('Yes').concept_id == tests.value_coded

                          elsif ConceptName.find_by_name('DBS Specimen ID').concept_id == tests.concept_id

                              str = tests.value_text.size
                              digits = tests.value_text.count('0123456789')
                              letters = str.to_i - digits.to_i

                            @data["specimen_ids_valid_ids_entered"].push(client.person_id) if digits == 5 && letters == 2
                            @data["specimen_ids_invalid_entry"].push(client.person_id) if digits != 5 || letters != 2

                         end


                    end

              end
        end

        def fetch_retest_referral

          Person.joins("INNER JOIN encounter e ON e.patient_id = person.person_id AND e.encounter_type = #{EncounterType.find_by_name("APPOINTMENT").encounter_type_id} AND e.voided = 0 AND e.program_id = #{Program.find_by_name("HTC Program").program_id}")
                .joins("INNER JOIN obs ON obs.person_id = e.patient_id AND obs.voided = 0 AND obs.concept_id = #{ConceptName.find_by_name('Referral for Re-Testing').concept_id} AND e.encounter_id = obs.encounter_id")
                .select("person.person_id person_id,obs.value_text value")
                .where("person.voided = 0 AND DATE(e.encounter_datetime) BETWEEN '#{start_date}' AND '#{end_date}' + INTERVAL 1 DAY")
                .each do |client|

                     @data['referral_for_retesting_after_confirmatory_no'].push(client.person_id) if client.value == 'None'
                     @data['referral_for_retesting_after_confirmatory_yes'].push(client.person_id) if client.value == 'Re-Test'
                  
              end
        end

        def fetch_art_referral

          Person.joins("INNER JOIN encounter e ON e.patient_id = person.person_id AND e.encounter_type = #{EncounterType.find_by_name("TESTING").encounter_type_id} AND e.voided = 0 AND e.program_id = #{Program.find_by_name("HTC Program").program_id}")
          .joins("INNER JOIN obs o1 ON o1.person_id = e.patient_id AND o1.voided = 0 AND o1.concept_id = #{ConceptName.find_by_name('HIV status').concept_id} AND o1.value_coded = #{ConceptName.find_by_name('Positive').concept_id} AND e.encounter_id = o1.encounter_id")
          .select("person.person_id person_id")
          .where("person.voided = 0 AND DATE(e.encounter_datetime) BETWEEN '#{start_date}' AND '#{end_date}' + INTERVAL 1 DAY")
          .each do |client|

            obs = Observation.joins(:encounter)\
                             .where(concept: concept('Referrals ordered'),
                                     person: client.person_id,
                 encounter: { encounter_type: EncounterType.find_by_name("REFERRAL").encounter_type_id,
                                  program_id: Program.find_by_name("HTC Program").program_id })\
            .where("encounter_datetime BETWEEN '#{start_date}' AND '#{end_date}' + INTERVAL 1 DAY ")\
            .last

               if obs.blank?                  
                   @data['referral_for_art_initiation_no'].push(client.person_id)                  
               else
                  @data['referral_for_art_initiation_yes'].push(client.person_id) if obs.value_text == 'ART'              
               end
           
             end
         end

        def fetch_art_referral_outcome

          Person.joins("INNER JOIN encounter e ON e.patient_id = person.person_id AND e.encounter_type = #{EncounterType.find_by_name("ART_FOLLOWUP").encounter_type_id} AND e.voided = 0 AND e.program_id = #{Program.find_by_name("HTC Program").program_id}")
                .joins("INNER JOIN obs ON obs.person_id = e.patient_id AND obs.voided = 0 AND obs.concept_id = #{ConceptName.find_by_name('ART referral').concept_id} AND e.encounter_id = obs.encounter_id")
                .select("person.person_id person_id,obs.value_coded value_coded")
                .where("person.voided = 0 AND DATE(e.encounter_datetime) BETWEEN '#{start_date}' AND '#{end_date}' + INTERVAL 1 DAY")
                .each do |client|

                     @data['art_referral_outcome_linked'].push(client.person_id) if ConceptName.find_by_name('Link').concept_id == client.value_coded
                     @data['art_referral_outcome_refused'].push(client.person_id) if ConceptName.find_by_name('Refused').concept_id == client.value_coded
                     @data['art_referral_outcome_died'].push(client.person_id) if ConceptName.find_by_name('Died').concept_id == client.value_coded
                     @data['art_referral_outcome_unknown'].push(client.person_id) if ConceptName.find_by_name('Unknown').concept_id == client.value_coded 
                     
              end
        end





      end
    end
  end
end
