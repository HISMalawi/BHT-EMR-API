# frozen_string_literal: true

module ARTService
  module Reports
    ##
    # Patients newly initiated on TPT disaggregated by regimen type and age group.
    #
    # Newly initiated is defined as patients who have received TPT for the first
    # time in the reporting period or patients who have gone on a TPT course
    # break for a period that is at least 9 months long before restarting TPT
    # in the current reporting period.
    class TptNewlyInitiated
      attr_reader :start_date, :end_date

      def initialize(start_date:, end_date:, **_kwargs)
        @start_date = ActiveRecord::Base.connection.quote(start_date)
        @end_date = ActiveRecord::Base.connection.quote(end_date)
      end

      def find_report
        newly_initiated_on_tpt.each_with_object(init_report) do |patient, report|
          age_group = patient['age_group']
          gender = patient['gender']&.strip&.first&.upcase || 'Unknown'
          course = patient_on_3hp?(patient) ? '3HP' : '6H'

          report[age_group][course][gender] << patient
        end
      end

      private

      AGE_GROUPS = [
        'Unknown',
        '0-5 months',
        '6-11 months',
        '12-23 months',
        '2-4 years',
        '5-9 years',
        '10-14 years',
        '15-17 years',
        '18-19 years',
        '20-24 years',
        '25-29 years',
        '30-34 years',
        '35-39 years',
        '40-44 years',
        '45-49 years',
        '50 plus years'
      ].freeze

      def init_report
        AGE_GROUPS.each_with_object({}) do |age_group, report|
          report[age_group] = {
            '3HP' => { 'M' => [], 'F' => [], 'Unknown' => [] },
            '6H' => { 'M' => [], 'F' => [], 'Unknown' => [] }
          }
        end
      end

      def patient_on_3hp?(patient)
        patient['drug_concepts'].split(',').collect(&:to_i).include?(rifapentine_concept.concept_id)
      end

      def rifapentine_concept
        @rifapentine_concept ||= ConceptName.find_by!(name: 'Rifapentine')
      end

      def newly_initiated_on_tpt
        ActiveRecord::Base.connection.select_all <<~SQL
          SELECT patient_program.patient_id,
                 cohort_disaggregated_age_group(person.birthdate, DATE(#{end_date})) AS age_group,
                 DATE(prescription_encounter.encounter_datetime) AS prescription_date,
                 person_name.given_name,
                 person_name.family_name,
                 person.birthdate,
                 person.gender,
                 patient_identifier.identifier AS arv_number,
                 GROUP_CONCAT(DISTINCT orders.concept_id SEPARATOR ',') AS drug_concepts
          FROM person
          LEFT JOIN person_name
            ON person_name.person_id = person.person_id
            AND person_name.voided = 0
          LEFT JOIN patient_identifier
            ON patient_identifier.patient_id = person.person_id
            AND patient_identifier.identifier_type IN (SELECT patient_identifier_type_id FROM patient_identifier_type WHERE name = 'ARV Number')
            AND patient_identifier.voided = 0
          INNER JOIN patient_program
            ON patient_program.patient_id = person.person_id
            AND patient_program.program_id IN (SELECT program_id FROM program WHERE name = 'HIV Program')
          INNER JOIN encounter AS prescription_encounter
            ON prescription_encounter.patient_id = person.person_id
            AND prescription_encounter.encounter_type IN (SELECT encounter_type_id FROM encounter_type WHERE name = 'Treatment')
            AND prescription_encounter.program_id IN (SELECT program_id FROM program WHERE name = 'HIV Program')
            AND prescription_encounter.encounter_datetime >= #{start_date}
            AND prescription_encounter.encounter_datetime < DATE(#{end_date}) + INTERVAL 1 DAY
            AND prescription_encounter.voided = 0
          INNER JOIN orders AS orders
            ON orders.encounter_id = prescription_encounter.encounter_id
            AND orders.order_type_id = (SELECT order_type_id FROM order_type WHERE name = 'Drug order' LIMIT 1)
            AND orders.start_date >= #{start_date}
            AND orders.start_date < DATE(#{end_date}) + INTERVAL 1 DAY
            AND orders.voided = 0
          INNER JOIN drug_order
            ON drug_order.order_id = orders.order_id
            AND drug_order.quantity > 0  /* This implies that a dispensation was made */
          INNER JOIN drug
            ON drug.drug_id = drug_order.drug_inventory_id
          INNER JOIN concept_name AS tpt_drug_concepts
            ON tpt_drug_concepts.concept_id = drug.concept_id
            AND tpt_drug_concepts.name IN ('Rifapentine', 'Isoniazid')
            AND tpt_drug_concepts.voided = 0
          WHERE patient_program.patient_id NOT IN (
            /* Filter out patients who received TPT before current reporting period */
            SELECT DISTINCT patient_program.patient_id
            FROM patient_program
            INNER JOIN encounter AS prescription_encounter
              ON prescription_encounter.patient_id = patient_program.patient_id
              AND prescription_encounter.encounter_type IN (SELECT encounter_type_id FROM encounter_type WHERE name = 'Treatment')
              AND prescription_encounter.program_id = (SELECT program_id FROM program WHERE name = 'HIV Program' LIMIT 1)
              AND prescription_encounter.voided = 0
            INNER JOIN orders
              ON orders.encounter_id = prescription_encounter.encounter_id
              AND orders.order_type_id = (SELECT order_type_id FROM order_type WHERE name = 'Drug order' LIMIT 1)
              AND orders.start_date < #{start_date}
              /* Re-initiates defined as those who stopped TPT for a period of at least 9 months
                 and have restarted TPT are also included in the report */
              AND orders.start_date >= DATE(#{start_date}) - INTERVAL 9 MONTH
              AND orders.voided = 0
            INNER JOIN concept_name AS tpt_drug_concepts
              ON tpt_drug_concepts.concept_id = orders.concept_id
              AND tpt_drug_concepts.name IN ('Rifapentine', 'Isoniazid')
              AND tpt_drug_concepts.voided = 0
            INNER JOIN drug_order AS drug_order
              ON drug_order.order_id = orders.order_id
              AND drug_order.quantity > 0
            WHERE patient_program.program_id IN (SELECT program_id FROM program WHERE name = 'HIV Program')
          ) AND patient_program.patient_id NOT IN (
            /* External consultations */
            SELECT DISTINCT registration_encounter.patient_id
            FROM patient_program
            INNER JOIN program ON program.name = 'HIV Program'
            INNER JOIN encounter AS registration_encounter
              ON registration_encounter.patient_id = patient_program.patient_id
              AND registration_encounter.program_id = patient_program.program_id
              AND registration_encounter.encounter_datetime < DATE(#{end_date}) + INTERVAL 1 DAY
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
              WHERE encounter.encounter_datetime < DATE(#{end_date}) AND encounter.voided = 0
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
          GROUP BY patient_program.patient_id
        SQL
      end
    end
  end
end
