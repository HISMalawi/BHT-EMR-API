# frozen_string_literal:true

# Fetches all clients that are not new patients at between the specified period
module ARTService
  module Reports
    class ExternalConsultationClients
      def initialize(start_date:, end_date:)
        @start_date = start_date.to_date
        @end_date = end_date.to_date
      end

      def list
        other_clients
      end

      private

      def other_clients
        ext_consultation_concept_id = ConceptName.find_by_name('External consultation').concept_id
        drug_refill_concept_id = ConceptName.find_by_name('Drug refill').concept_id
        # internal_client_concept_id = ConceptName.find_by_name('New patient').concept_id
        type_of_client_concept_id = ConceptName.find_by_name('Type of patient').concept_id
        npid_identifier_type_id = PatientIdentifierType.find_by_name('National ID').id

        possible_clients = ActiveRecord::Base.connection.select_all <<~SQL
          SELECT
          	p.person_id patient_id, npid.identifier npid, main.value_coded,
          	p.birthdate, p.gender, main.obs_datetime, n.family_name, n.given_name, main.value_coded
          FROM obs main
          INNER JOIN person p ON p.person_id = main.person_id
          LEFT JOIN patient_identifier npid ON npid.patient_id = p.person_id
          AND npid.identifier_type = #{npid_identifier_type_id} AND npid.voided = 0
          LEFT JOIN person_name n ON n.person_id = p.person_id AND n.voided = 0
          INNER JOIN (
          	SELECT person_id, MAX(obs_datetime) as obs_datetime, concept_id FROM obs
          	WHERE concept_id = #{type_of_client_concept_id}
          	AND voided = 0
          	AND obs.obs_datetime BETWEEN "#{@start_date.strftime('%Y-%m-%d 00:00:00')}"
          	AND "#{@end_date.strftime('%Y-%m-%d 23:59:59')}"
          	GROUP BY person_id
          ) sub_group ON main.person_id = sub_group.person_id
          AND main.obs_datetime = sub_group.obs_datetime
          AND main.concept_id = sub_group.concept_id
          WHERE main.value_coded IN (#{ext_consultation_concept_id}, #{drug_refill_concept_id})
          ORDER BY n.date_created DESC
        SQL

        (possible_clients || []).map do |client|
          {
            patient_id: client['patient_id'].to_i,
            patient_type: client['value_coded'] == ext_consultation_concept_id ? 'External consultation' : 'Drug refill',
            npid: client['npid'],
            birthdate: client['birthdate'].to_date,
            gender: client['gender'],
            given_name: client['given_name'],
            family_name: client['family_name'],
            date_set: client['obs_datetime'].to_date
          }
        end
      end
    end
  end
end
