module CXCAService
  module Reports
		module Clinic


			class BookedClientsFromArtRawData
				def initialize(start_date:, end_date:)
					@start_date = start_date.strftime('%Y-%m-%d 00:00:00')
					@end_date = end_date.strftime('%Y-%m-%d 23:59:59')
				end

				def data
					return raw_data
				end

				private

				def raw_data
					offer_cxca = ConceptName.find_by_name 'Offer CxCa'
					offer_cxca_yes = ConceptName.find_by_name 'Yes'
					reason_for_visit = ConceptName.find_by_name 'Reason for visit'
					hiv_program_id = Program.find_by_name("HIV PROGRAM").id

					people = Person.joins("LEFT JOIN obs ON person.person_id = obs.person_id
						AND obs.concept_id = #{reason_for_visit.concept_id}
						AND obs.obs_datetime BETWEEN '#{@start_date}' AND '#{@end_date}' AND obs.voided = 0
						LEFT JOIN patient_identifier i ON i.patient_id = person.person_id
						AND i.voided = 0 AND identifier_type = 3
						LEFT JOIN person_name names ON names.person_id = person.person_id AND names.voided = 0
						INNER JOIN (SELECT o.* FROM obs o INNER JOIN encounter e ON e.encounter_id = o.encounter_id
						WHERE o.concept_id = #{offer_cxca.concept_id} AND o.obs_datetime
						BETWEEN '#{@start_date}' AND '#{@end_date}' AND o.voided = 0
						AND e.program_id = #{hiv_program_id} AND o.value_coded = #{offer_cxca_yes.concept_id})
						cxca ON cxca.person_id = person.person_id").group("person.person_id").\
						select("person.person_id, obs.value_coded, birthdate,
							identifier,	gender, given_name, family_name, cxca.obs_datetime")


					clients = []

					(people || []).each do |person|
						seen = person.value_coded.blank? ? false : true
						clients.push({
							person_id: person.person_id,
							dob: (person.birthdate.strftime("%d/%b/%Y") rescue 'N/A'),
							gender: person.gender,
							given_name: person.given_name,
							family_name: person.family_name,
							seen: seen,
							booked_date: person.obs_datetime.strftime("%d/%b/%Y"),
							identifier: person.identifier
						})
					end

					return clients
				end

			end


		end
	end
end