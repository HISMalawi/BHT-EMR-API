module CXCAService
  module Reports
		module Moh


			class ScreenedForCxcaDisaggregatedByHivStatus
				def initialize(start_date:, end_date:)
					@start_date = start_date.strftime('%Y-%m-%d 00:00:00')
					@end_date = end_date.strftime('%Y-%m-%d 23:59:59')
				end

				def data
					return screened
				end

				private

				def screened
					screening_method = concept 'CxCa screening method'
					hiv_status = concept 'HIV status'

					obs = Observation.where("obs.concept_id = ? AND p.gender IN(?)
					AND obs.obs_datetime BETWEEN ? AND ?", screening_method.concept_id,
					['F','Female'], @start_date, @end_date).\
					joins("INNER JOIN person p ON p.person_id = obs.person_id
					INNER JOIN concept_name m ON m.concept_id = obs.value_coded
					INNER JOIN obs hiv_status ON hiv_status.person_id = obs.person_id
					AND hiv_status.concept_id = #{hiv_status.concept_id}
					INNER JOIN concept_name h ON hiv_status.value_coded = h.concept_id").\
					group("p.person_id, DATE(obs.obs_datetime)").select("p.birthdate, m.concept_id, m.name, obs.obs_datetime,
					TIMESTAMPDIFF(year, p.birthdate, DATE(obs.obs_datetime)) age, h.name hiv_status").\
					order("hiv_status.obs_datetime DESC")

					formated_obs = []
					(obs || []).each do |ob|
						formated_obs << {
							patient_id: ob.person_id,
							screened_method: ob.name,
							birthdate: ob.birthdate,
							obs_datetime: ob.obs_datetime.to_date,
							age_in_years: ob.age,
							hiv_status: ob.hiv_status
						}
					end

					return formated_obs
				end

				def concept(name)
					ConceptName.find_by_name(name)
				end
			end

		end
	end
end