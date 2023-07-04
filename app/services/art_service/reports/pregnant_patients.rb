# frozen_string_literal: true

module ArtService
  module Reports
    # Retrieve all pregnant females in a given time period
    class PregnantPatients
      attr_reader :start_date, :end_date

      def initialize(start_date:, end_date:, **_kwargs)
        @start_date = start_date
        @end_date = end_date
      end

      def find_report
        all_pregnant.map do |patient|
          {
            patient_id: patient.patient_id,
            arv_number: patient.arv_number,
            given_name: patient.given_name,
            family_name: patient.family_name,
            gender: patient.gender,
            birthdate: patient.birthdate,
            last_reported_date: patient.last_reported_date
          }
        end
      end

      private

      def all_pregnant
        str_start_date = ActiveRecord::Base.connection.quote(start_date)
        str_end_date = ActiveRecord::Base.connection.quote(end_date)

        Person.find_by_sql(
          <<~SQL
            SELECT obs.person_id AS patient_id,
                   patient_identifier.identifier AS arv_number,
                   given_name,
                   family_name,
                   gender,
                   birthdate,
                   obs.obs_datetime AS last_reported_date
            FROM obs INNER JOIN person ON person.person_id = obs.person_id
              INNER JOIN person_name ON person_name.person_id = obs.person_id
              LEFT JOIN patient_identifier ON patient_identifier.patient_id = obs.person_id
                AND patient_identifier.identifier_type = #{arv_number_type_id}
              INNER JOIN encounter ON encounter.encounter_id = obs.encounter_id
                AND encounter.program_id = #{hiv_program_id}
            WHERE obs.concept_id IN (#{pregnant_concepts.select(:concept_id).to_sql})
                  AND obs.value_coded = #{yes_concept_id}
                  AND obs.person_id IN (#{patients_on_treatment.to_sql})
                  AND obs.obs_datetime = (
                    SELECT MAX(obs_date.obs_datetime) FROM obs obs_date
                      INNER JOIN encounter USING (encounter_id)
                    WHERE obs_date.concept_id IN (#{pregnant_concepts.select(:concept_id).to_sql})
                      AND obs_date.obs_datetime BETWEEN #{str_start_date} AND #{str_end_date}
                      AND obs_date.person_id = obs.person_id
                      AND program_id = #{hiv_program_id}
                  )
            GROUP BY obs.person_id
          SQL
        )
      end

      def patients_on_treatment
        PatientsOnTreatment.within(start_date, end_date)
      end

      def pregnant_concepts
        ConceptName.where(name: ['Is patient pregnant?', 'patient_pregnant'])
      end

      def yes_concept_id
        ConceptName.find_by_name('Yes').concept_id
      end

      def arv_number_type_id
        PatientIdentifierType.find_by_name('ARV Number').id
      end

      def hiv_program_id
        ArtService::Constants::PROGRAM_ID
      end
    end
  end
end
