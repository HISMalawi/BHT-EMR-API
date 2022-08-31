# frozen_string_literal: true

module ArtService
  module Reports
    ##
    # Family planning, action to take
    # It should pull data for 6 month back e.g when the report is generated for the month of June,
    # the report must pick clients who started TPT in the month of December
    # it must be drillable
    class ClinicTptOutcome
      include ModelUtils

      def initialize(start_date:, end_date:)
        @start_date = start_date
        @end_date = end_date
      end

      def find_report
        tpt_clients
      end

      private

      TPT_TYPES = %w[3HP 6H].freeze

      def prepare_tpt_clients_response_structure
        structure = TPT_TYPES.each do |tpt_type|
          ARTService::Reports::Pepfar::Utils.pepfar_age_groups.each do |age_group|
            structure[tpt_type][age_group] = {
              'Started TPT' => [],
              'Completed TPT' => [],
              'Not Completed TPT' => [],
              'Died' => [],
              'Stopped ART' => [],
              'Defaulted' => [],
              'TO' => [],
              'Confirmed TB' => [],
              'Pregnant' => []
            }
          end
        end
      end

      def tpt_clients
        ActiveRecord::Base.connection.select_all <<~SQL
          SELECT
            p.person_id AS patient_id,
            DATE(min(o.start_date)) AS start_date,
            patient_outcome(p.person_id, DATE('#{@end_date}')) AS outcome,
            SUM(d.quantity) AS total_pills_taken,
            SUM(DATEDIFF(o.auto_expire_date, o.start_date)) AS total_days_on_medication,
            p.gender,
            p.birthdate,
            disaggregated_age_group(p.birthdate, DATE('#{@end_date}')) AS age_group,
            GROUP_CONCAT(DISTINCT o.concept_id SEPARATOR ',') AS drug_concepts
          FROM person p
          INNER JOIN encounter e
            ON e.patient_id = p.person_id
            AND e.encounter_type = #{EncounterType.find_by_name('Treatment').id}
            AND e.voided = 0
            AND e.program_id = #{Program.find_by_name('HIV PROGRAM').id}
            AND e.encounter_datetime >= DATE('#{@start_date}') - INTERVAL 6 MONTH
            AND e.encounter_datetime <= DATE('#{@start_date}')
          INNER JOIN orders o
            ON o.patient_id = e.patient_id
            AND o.concept_id IN (#{tpt_drugs.to_sql})
            AND o.start_date >= DATE('#{@start_date}') - INTERVAL 6 MONTH
            AND o.start_date <= DATE('#{@end_date}')
            AND o.voided = 0
            AND o.order_type_id = #{OrderType.find_by_name('Drug order').id}
          INNER JOIN drug_order d ON d.order_id = o.order_id AND d.quantity > 0
          WHERE p.voided = 0
          AND p.person_id NOT IN (
            SELECT p.person_id
            FROM person p
            INNER JOIN encounter e
              ON e.patient_id = p.person_id
              AND e.encounter_type = #{EncounterType.find_by_name('Treatment').id}
              AND e.voided = 0
              AND e.program_id = #{Program.find_by_name('HIV PROGRAM').id}
            INNER JOIN orders o
              ON o.patient_id = e.patient_id
              AND o.concept_id IN (#{tpt_drugs.to_sql})
              AND o.voided = 0
              AND o.order_type_id = #{OrderType.find_by_name('Drug order').id}
            INNER JOIN drug_order d ON d.order_id = o.order_id AND d.quantity > 0
            WHERE p.voided = 0
              AND e.encounter_datetime < '#{@start_date - 6.months}'
              AND e.encounter_datetime >= '#{@start_date - 15.months}'
          )
          AND p.person_id NOT IN (
            /* External consultations */
            SELECT DISTINCT registration_encounter.patient_id
            FROM patient_program
            INNER JOIN program ON program.name = 'HIV Program'
            INNER JOIN encounter AS registration_encounter
              ON registration_encounter.patient_id = patient_program.patient_id
              AND registration_encounter.program_id = patient_program.program_id
              AND registration_encounter.encounter_datetime < DATE(#{@end_date}) + INTERVAL 1 DAY
              AND registration_encounter.voided = 0
            INNER JOIN (
              SELECT MAX(encounter.encounter_datetime) AS encounter_datetime, encounter.patient_id
              FROM encounter
              INNER JOIN encounter_type
                ON encounter_type.encounter_type_id = encounter.encounter_type
                AND encounter_type.name = 'Registration'
              INNER JOIN program
                ON program.program_id = encounter.program_id
                AND program.name = 'HIV Program'
              WHERE encounter.encounter_datetime < DATE(#{@end_date}) AND encounter.voided = 0
              GROUP BY encounter.patient_id
            ) AS max_registration_encounter
              ON max_registration_encounter.patient_id = registration_encounter.patient_id
              AND max_registration_encounter.encounter_datetime = registration_encounter.encounter_datetime
            INNER JOIN obs AS patient_type_obs
              ON patient_type_obs.encounter_id = registration_encounter.encounter_id
              AND patient_type_obs.concept_id IN (SELECT concept_id FROM concept_name WHERE name = 'Type of patient' AND voided = 0)
              AND patient_type_obs.value_coded IN (SELECT concept_id FROM concept_name WHERE name IN ('Drug refill', 'External consultation') AND voided = 0)
              AND patient_type_obs.voided = 0
            WHERE patient_program.voided = 0
          )
          GROUP BY p.person_id
        SQL
      end

      def tpt_drugs
        ConceptName.where(name: ['INH', 'Isoniazid/Rifapentine', 'Rifapentine']).select(:concept_id)
      end
    end
  end
end
