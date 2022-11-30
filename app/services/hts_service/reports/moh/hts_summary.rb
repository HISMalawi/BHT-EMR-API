# frozen_string_literal: true

module HtsService
  module Reports
    module Moh
      # HTS Summary report
      class HtsSummary
        attr_accessor :start_date, :end_date

        def initialize(start_date:, end_date:)
          @start_date = start_date
          @end_date = end_date
          @data = {
            "total_clients_tested_for_hiv" =>[],
            "new_negative" => [],
            "new_positive_total" =>[],
            "new_positive_male" => [],
            "new_positive_female" => [],
            "confirmatory_positive_total_prev_pos_professional_test" =>[],
            "confirmed_positive_male" =>[],
            "confirmed_positive_female" =>[],
            "confirmatory_inconclusive_total_prev_pos_professional_test" =>[],
            "confirmed_inconclusive_male" => [],
            "confirmed_inconclusive_female" =>[],
            "new_exposed_infant" => [],
            "new_inconclusive" => []
           }
        end

        def data
          report = init_report
          response = @data
        end

        private

        def init_report

          fetch_clients_tested
          fetch_confirmatory_clients('Confirmatory Positive')
          fetch_confirmatory_clients("Confirmatory Inconclusive")
          fetch_new_clients("New exposed infant")
          fetch_new_clients("New Inconclusive")
          set_unique
        end

        def set_unique

          @data.each do |key, array|    
              @data[key]  =  array.uniq
          end

        end

        def fetch_clients_tested

          Person.joins("INNER JOIN encounter e ON e.patient_id = person.person_id AND e.encounter_type = #{EncounterType.find_by_name("TESTING").encounter_type_id} AND e.voided = 0 AND e.program_id = #{Program.find_by_name("HTC Program").program_id}")
                .joins("INNER JOIN obs ON obs.person_id = e.patient_id AND obs.voided = 0")
                .select("person.person_id person_id,obs.value_coded concept_id,person.gender gender")
                .where(obs:{concept_id:ConceptName.find_by_name('HIV status').concept_id})
          .where("person.voided = 0 AND DATE(e.encounter_datetime) BETWEEN '#{start_date}' AND '#{end_date}' + INTERVAL 1 DAY")
          .each do |client|

                    @data['total_clients_tested_for_hiv'].push(client.person_id)
                    @data['new_negative'].push(client.person_id) if ConceptName.find_by_name('NEGATIVE').concept_id == client.concept_id
                    @data['new_positive_total'].push(client.person_id) if ConceptName.find_by_name('POSITIVE').concept_id == client.concept_id
                    @data['new_positive_male'].push(client.person_id) if ConceptName.find_by_name('POSITIVE').concept_id == client.concept_id && client.gender == "M"
                    @data['new_positive_female'].push(client.person_id) if ConceptName.find_by_name('POSITIVE').concept_id == client.concept_id && client.gender == "F"
              end
        end
        def fetch_confirmatory_clients(indicator)

          Person.joins("INNER JOIN encounter e ON e.patient_id = person.person_id AND e.encounter_type = #{EncounterType.find_by_name("TESTING").encounter_type_id} AND e.voided = 0 AND e.program_id = #{Program.find_by_name("HTC Program").program_id}")
                .joins("INNER JOIN obs o1 ON o1.person_id = e.patient_id AND o1.voided = 0 AND o1.concept_id = #{ConceptName.find_by_name('HIV test type').concept_id} AND e.encounter_id = o1.encounter_id")
                .joins("INNER JOIN obs o2 ON o2.person_id = e.patient_id AND o2.voided = 0 AND o2.concept_id = #{ConceptName.find_by_name('Previous HIV Test Results').concept_id} AND o1.encounter_id = o2.encounter_id")
                .joins("INNER JOIN obs o3 ON o3.person_id = e.patient_id AND o3.voided = 0 AND o3.concept_id = #{ConceptName.find_by_name('Previous HIV Test done').concept_id} AND o2.encounter_id = o3.encounter_id")
                .select("person.person_id person_id,person.gender gender")
                .where(o1:{value_coded:ConceptName.find_by_name('Confirmatory HIV test').concept_id},
                       o2:{value_coded:ConceptName.find_by_name("#{indicator}").concept_id},
                       o3:{value_coded:ConceptName.find_by_name('Professional').concept_id})
                .where("person.voided = 0 AND DATE(e.encounter_datetime) BETWEEN '#{start_date}' AND '#{end_date}' + INTERVAL 1 DAY")
                .each do |client|

                  @data['confirmatory_positive_total_prev_pos_professional_test'].push(client.person_id) if indicator == 'Confirmatory Positive'
                  @data['confirmed_positive_male'].push(client.person_id) if client.gender == "M" && indicator == 'Confirmatory Positive'
                  @data['confirmed_positive_female'].push(client.person_id) if client.gender == "F" && indicator == 'Confirmatory Positive'
                  @data['confirmatory_inconclusive_total_prev_pos_professional_test'].push(client.person_id) if indicator == 'Confirmatory Inconclusive'
                  @data['confirmed_inconclusive_male'].push(client.person_id) if client.gender == "M" && indicator == 'Confirmatory Inconclusive'
                  @data['confirmed_inconclusive_female'].push(client.person_id) if client.gender == "F" && indicator == 'Confirmatory Inconclusive'

                end
        end

        def fetch_new_clients(indicator)

          Person.joins("INNER JOIN encounter e ON e.patient_id = person.person_id AND e.encounter_type = #{EncounterType.find_by_name("TESTING").encounter_type_id} AND e.voided = 0 AND e.program_id = #{Program.find_by_name("HTC Program").program_id}")
                .joins("INNER JOIN obs o1 ON o1.person_id = e.patient_id AND o1.voided = 0 AND o1.concept_id = #{ConceptName.find_by_name('HIV test type').concept_id} AND e.encounter_id = o1.encounter_id")
                .joins("INNER JOIN obs o2 ON o2.person_id = e.patient_id AND o2.voided = 0 AND o2.concept_id = #{ConceptName.find_by_name('Previous HIV Test Results').concept_id} AND o1.encounter_id = o2.encounter_id")
                .select("person.person_id person_id,person.gender gender")
                .where(o1:{value_coded:ConceptName.find_by_name('Confirmatory HIV test').concept_id},
                       o2:{value_coded:ConceptName.find_by_name("#{indicator}").concept_id})
                .where("person.voided = 0 AND DATE(e.encounter_datetime) BETWEEN '#{start_date}' AND '#{end_date}' + INTERVAL 1 DAY")
                .each do |client|

                  @data['new_exposed_infant'].push(client.person_id) if indicator == 'New exposed infant'
                  @data['new_inconclusive'].push(client.person_id) if indicator == 'New Inconclusive'

                end
        end


      end
    end
  end
end
