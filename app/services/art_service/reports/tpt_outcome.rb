# frozen_string_literal: true

module ARTService
  module Reports
    ##
    # Family planning, action to take
    # It should pull data for 6 month back e.g when the report is generated for the month of June,
    # the report must pick clients who started TPT in the month of December
    # it must be drillable
    class TptOutcome
      include ModelUtils
      include ARTService::Reports::Pepfar::Utils

      def initialize(start_date:, end_date:, **_kwarg)
        @start_date = start_date.to_date
        @end_date = end_date.to_date
      end

      def find_report
        report = init_report
        load_patients_into_report report, tpt_clients
        response = []
        report.each do |key, value|
          response << { age_group: key, tpt_type: '3HP', **value['3HP'] }
          response << { age_group: key, tpt_type: '6H', **value['6H'] }
        end
        response
      end

      private

      TPT_TYPES = %w[3HP 6H].freeze

      def init_report
        pepfar_age_groups.each_with_object({}) do |age_group, report|
          next if age_group == 'Unknown'

          report[age_group] = TPT_TYPES.each_with_object({}) do |tpt_type, tpt_report|
            tpt_report[tpt_type] = {
              started_tpt: [],
              completed_tpt: [],
              not_completed_tpt: [],
              died: [],
              stopped: [],
              defaulted: [],
              transfer_out: [],
              confirmed_tb: [],
              pregnant: []
            }
          end
        end
      end

      def patient_pregnant?(patient_id, last_tpt)
        Observation.where(person_id: patient_id, concept_id: pregnant_concept_id,
                          value_coded: yes_concept_id)
                   .where('DATE(obs_datetime) > DATE(?) AND DATE(obs_datetime) < DATE(?) + INTERVAL 1 DAY', last_tpt.to_date, @end_date.to_date)
                   .exists?
      end

      def patient_on_tb_treatment?(patient_id, last_tpt)
        Observation.where(person_id: patient_id, concept_id: tb_treatment_concept_id,
                          value_coded: yes_concept_id)
                   .where('DATE(obs_datetime) > DATE(?) AND DATE(obs_datetime) < DATE(?) + INTERVAL 1 DAY', last_tpt.to_date, @end_date.to_date)
                   .exists?
      end

      def pregnant_concept_id
        @pregnant_concept_id ||= concept_name_to_id('Is patient pregnant?')
      end

      def tb_treatment_concept_id
        @tb_treatment_concept_id ||= concept_name_to_id('TB treatment')
      end

      def yes_concept_id
        @yes_concept_id ||= concept_name_to_id('Yes')
      end

      def tpt_clients
        ActiveRecord::Base.connection.select_all <<~SQL
          SELECT
            p.person_id AS patient_id,
            DATE(min(o.start_date)) AS start_date,
            DATE(max(o.start_date)) AS last_dispense_date,
            patient_outcome(p.person_id, DATE('#{@end_date}')) AS outcome,
            SUM(d.quantity) AS total_pills_taken,
            SUM(DATEDIFF(o.auto_expire_date, o.start_date)) AS total_days_on_medication,
            p.gender,
            p.birthdate,
            disaggregated_age_group(p.birthdate, DATE('#{@end_date}')) AS age_group,
            GROUP_CONCAT(DISTINCT o.concept_id SEPARATOR ',') AS drug_concepts,
            CASE
              WHEN count(DISTINCT o.concept_id) >  1 THEN '3HP'
              WHEN o.concept_id = 10565 THEN '3HP'
              ELSE '6H'
            END AS tpt_type
          FROM person p
          INNER JOIN encounter e
            ON e.patient_id = p.person_id
            AND e.encounter_type = #{EncounterType.find_by_name('Treatment').id}
            AND e.voided = 0
            AND e.program_id = #{Program.find_by_name('HIV PROGRAM').id}
            AND e.encounter_datetime >= DATE('#{@start_date}') - INTERVAL 6 MONTH
            AND e.encounter_datetime <= DATE('#{@start_date}')
          INNER JOIN orders o
            ON o.encounter_id = e.encounter_id
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

      def load_patients_into_report(report, patients)
        patients.each do |patient|
          report[patient['age_group']][patient['tpt_type']][:started_tpt] << patient['patient_id']
          if patient_completed_tpt?(patient, patient['tpt_type'])
            report[patient['age_group']][patient['tpt_type']][:completed_tpt] << patient['patient_id']
          else
            report[patient['age_group']][patient['tpt_type']][:not_completed_tpt] << patient['patient_id']
            process_outcomes report, patient
          end
        end
      end

      def process_outcomes(report, patient)
        case patient['outcome']
        when 'Patient died'
          report[patient['age_group']][patient['tpt_type']][:died] << patient['patient_id']
        when 'Patient transferred out'
          report[patient['age_group']][patient['tpt_type']][:transfer_out] << patient['patient_id']
        when 'Treatment stopped'
          report[patient['age_group']][patient['tpt_type']][:stopped] << patient['patient_id']
        when 'Defaulted'
          report[patient['age_group']][patient['tpt_type']][:defaulted] << patient['patient_id']
        else
          process_patient_conditions report, patient
        end
      end

      def process_patient_conditions(report, patient)
        if patient_on_tb_treatment?(patient['patient_id'], patient['last_dispense_date'])
          report[patient['age_group']][patient['tpt_type']][:confirmed_tb] << patient['patient_id']
        elsif patient['gender'] == 'F' && patient_pregnant?(patient['patient_id'], patient['last_dispense_date'])
          report[patient['age_group']][patient['tpt_type']][:pregnant] << patient['patient_id']
        end
      end

      def tpt_drugs
        ConceptName.where(name: ['INH', 'Isoniazid/Rifapentine', 'Rifapentine']).select(:concept_id)
      end
    end
  end
end