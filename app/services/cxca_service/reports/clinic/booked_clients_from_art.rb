# frozen_string_literal: true

module CxcaService
  module Reports
    module Clinic
      class BookedClientsFromArt
        def initialize(start_date:, end_date:, **_kwargs)
          @start_date = start_date.strftime('%Y-%m-%d 00:00:00')
          @end_date = end_date.strftime('%Y-%m-%d 23:59:59')
        end

        def data
          disaggregated_data
        end

        private

        def disaggregated_data
          offer_cxca = ConceptName.find_by_name 'Offer CxCa'
          offer_cxca_yes = ConceptName.find_by_name 'Yes'
          reason_for_visit = ConceptName.find_by_name 'Reason for visit'
          hiv_program_id = Program.find_by_name('HIV PROGRAM').id

          people = Person.joins("LEFT JOIN obs ON person.person_id = obs.person_id
						AND obs.concept_id = #{reason_for_visit.concept_id}
						AND obs.obs_datetime BETWEEN '#{@start_date}' AND '#{@end_date}' AND obs.voided = 0
						INNER JOIN (SELECT o.* FROM obs o INNER JOIN encounter e ON e.encounter_id = o.encounter_id
						WHERE o.concept_id = #{offer_cxca.concept_id} AND o.obs_datetime
						BETWEEN '#{@start_date}' AND '#{@end_date}' AND o.voided = 0
						AND e.program_id = #{hiv_program_id} AND o.value_coded = #{offer_cxca_yes.concept_id})
						cxca ON cxca.person_id = person.person_id").group('person.person_id')\
                         .select("age(birthdate,DATE('#{@end_date}'), DATE(person.date_created),
						birthdate_estimated) age, person.person_id, obs.value_coded")

          age_groups = {}

          ['<25 years', '25-29 years', '30-44 years', '45-49 years', '>49 years'].each do |age_group|
            age_groups[age_group] = []
          end

          (people || []).each do |person|
            person_age = person.age
            screening_method_present = person.value_coded.blank? ? false : true
            if person_age < 25
              age_groups['<25 years'].push({
                                             person_id: person.person_id,
                                             screening_method_present:
                                           })
            elsif person_age >= 25 && person_age <= 29
              age_groups['25-29 years'].push({
                                               person_id: person.person_id,
                                               screening_method_present:
                                             })
            elsif person_age >= 30 && person_age <= 44
              age_groups['30-44 years'].push({
                                               person_id: person.person_id,
                                               screening_method_present:
                                             })
            elsif person_age >= 45 && person_age <= 49
              age_groups['45-49 years'].push({
                                               person_id: person.person_id,
                                               screening_method_present:
                                             })
            elsif person_age > 49
              age_groups['>49 years'].push({
                                             person_id: person.person_id,
                                             screening_method_present:
                                           })
            end
          end

          age_groups
        end
      end
    end
  end
end
