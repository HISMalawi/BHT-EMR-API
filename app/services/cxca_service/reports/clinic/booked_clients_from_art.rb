module CXCAService
  module Reports
		module Clinic


			class BookedClientsFromArt
				def initialize(start_date:, end_date:)
					@start_date = start_date.strftime('%Y-%m-%d 00:00:00')
					@end_date = end_date.strftime('%Y-%m-%d 23:59:59')
				end

				def data
					return disaggregated_data
				end

				private

				def disaggregated_data
					offer_cxca = ConceptName.find_by_name 'Offer CxCa'
					offer_cxca_yes = ConceptName.find_by_name 'Yes'
					screening_method = ConceptName.find_by_name 'CxCa screening method'

					people = Person.joins("INNER JOIN obs ON person.person_id = obs.person_id
						LEFT JOIN obs cxca ON cxca.person_id = person.person_id").\
						where("obs.concept_id = ? AND obs.value_coded = ? AND obs.obs_datetime BETWEEN ?
						AND ? AND cxca.concept_id = ? AND cxca.obs_datetime BETWEEN ?
						AND ?", offer_cxca.concept_id,offer_cxca_yes.concept_id,
						@start_date, @end_date,	screening_method.concept_id, @start_date, @end_date).\
						group("obs.concept_id, person.person_id").select("age(birthdate,DATE('#{@end_date}'),
						DATE(person.date_created), birthdate_estimated) age, person.person_id, cxca.value_coded")

					age_groups = {}

					['<25 years','25-29 years','30-44 years','45-49 years','>49 years'].each do |age_group|
						age_groups[age_group] = []
					end

					(people || []).each do |person|
						person_age = person.age
						screening_method_present = person.value_coded.blank? ? false : true
						if person_age < 25
							age_groups['<25 years'].push({
								person_id: person.person_id,
								screening_method_present: screening_method_present
							})
						elsif person_age >= 25 && person_age <= 29
							age_groups['25-29 years'].push({
								person_id: person.person_id,
								screening_method_present: screening_method_present
							})
						elsif person_age >= 30 && person_age <= 44
							age_groups['30-44 years'].push({
								person_id: person.person_id,
								screening_method_present: screening_method_present
							})
						elsif person_age >= 45 && person_age <= 49
							age_groups['45-49 years'].push({
								person_id: person.person_id,
								screening_method_present: screening_method_present
							})
						elsif person_age > 49
							age_groups['<49 years'].push({
								person_id: person.person_id,
								screening_method_present: screening_method_present
							})
						end
					end

					return age_groups
				end

			end


		end
	end
end