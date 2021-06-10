module ARTService
  module Reports

    class ExternalConsultationClients
      def initialize(start_date:, end_date:)
        @start_date = start_date.to_date
        @end_date = end_date.to_date
      end

			def list
				extenal_clients
			end

			private

			def extenal_clients
				ext_consultation_concept_id = ConceptName.find_by_name('External consultation').concept_id
				internal_client_concept_id = ConceptName.find_by_name('New patient').concept_id
				type_of_client_concept_id = ConceptName.find_by_name('Type of patient').concept_id
				arv_number_identifier_type_id = PatientIdentifierType.find_by_name('ARV number').id
				npid_identifier_type_id = PatientIdentifierType.find_by_name('National ID').id

				possible_clients = ActiveRecord::Base.connection.select_all <<~SQL
				SELECT
					p.person_id patient_id, a.identifier, npid.identifier npid, main.value_coded,
					p.birthdate, p.gender, main.obs_datetime, n.family_name, n.given_name
				FROM obs main
				INNER JOIN person p ON p.person_id = main.person_id
				LEFT JOIN patient_identifier a ON a.patient_id = p.person_id
				AND a.identifier_type = #{arv_number_identifier_type_id} AND a.voided = 0
				LEFT JOIN patient_identifier npid ON npid.patient_id = p.person_id
				AND npid.identifier_type = #{npid_identifier_type_id} AND npid.voided = 0
				LEFT JOIN person_name n ON n.person_id = p.person_id AND n.voided = 0
				WHERE main.obs_datetime = (
					SELECT MAX(obs_datetime) FROM obs WHERE obs.concept_id = #{type_of_client_concept_id}
					AND obs.value_coded IN(#{ext_consultation_concept_id}, #{internal_client_concept_id})
					AND obs.obs_datetime BETWEEN "#{@start_date.strftime('%Y-%m-%d 00:00:00')}"
					AND "#{@end_date.strftime('%Y-%m-%d 23:59:59')}"
					AND obs.person_id = main.person_id ORDER BY obs.date_created DESC)
				AND main.obs_datetime BETWEEN "#{@start_date.strftime('%Y-%m-%d 00:00:00')}"
				AND "#{@end_date.strftime('%Y-%m-%d 23:59:59')}" AND main.voided = 0
				AND main.value_coded IN(#{ext_consultation_concept_id}, #{internal_client_concept_id})
				AND p.voided = 0 GROUP BY main.person_id
				HAVING main.value_coded = #{ext_consultation_concept_id}
				ORDER BY n.date_created DESC;
				SQL

				(possible_clients || []).map do |client|
					{
						patient_id: client['patient_id'].to_i,
						npid: client['npid'],
						arv_number: client['identifier'],
						birthdate: (client['birthdate'].to_date rescue nil),
						gender: client['gender'],
						given_name: client['given_name'],
						family_name: client['family_name'],
						date_set: (client['obs_datetime'].to_date rescue nil)
					}
				end
			end


		end
	end
end
