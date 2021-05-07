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
        report = init_report

        load_patients_into_report(report, '3HP', newly_initiated_on_3hp)
        load_patients_into_report(report, '6H', newly_initiated_on_6h)

        report
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

      def load_patients_into_report(report, regimen, patients)
        patients.each do |patient|
          age_group = patient['age_group']
          gender = patient['gender']&.strip&.first&.upcase || 'Unknown'

          report[age_group][regimen][gender] << patient
        end
      end

      # 3HP new initiates
      def newly_initiated_on_3hp
        newly_initiated_on_tpt <<~SQL
          SELECT DISTINCT drug_id
          FROM drug
          INNER JOIN concept_name
            USING (concept_id)
          WHERE concept_name.name = 'Rifapentine'
        SQL
      end

      # IPT new initiates
      def newly_initiated_on_6h
        newly_initiated_on_tpt <<~SQL
          SELECT DISTINCT drug_id
          FROM drug
          INNER JOIN concept_name
            USING (concept_id)
          WHERE concept_name.name = 'Pyridoxine'
        SQL
      end

      def newly_initiated_on_tpt(primary_drug_query)
        ActiveRecord::Base.connection.select_all <<~SQL
          SELECT patient_program.patient_id,
                 cohort_disaggregated_age_group(person.birthdate, DATE(#{end_date})) AS age_group,
                 DATE(prescription_encounter.encounter_datetime) AS prescription_date,
                 person_name.given_name,
                 person_name.family_name,
                 person.birthdate,
                 person.gender,
                 patient_identifier.identifier AS arv_number
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
            AND drug_order.drug_inventory_id IN (#{primary_drug_query})
            AND drug_order.quantity > 0  /* This implies that a dispensation was made */
          INNER JOIN orders AS arv_orders
            ON arv_orders.patient_id = patient_program.patient_id
            AND arv_orders.start_date < DATE(#{end_date}) + INTERVAL 1 DAY
          INNER JOIN drug_order AS arv_drug_orders
            ON arv_drug_orders.order_id = arv_orders.order_id
            AND arv_drug_orders.drug_inventory_id IN (SELECT drug_id FROM arv_drug)
            AND arv_drug_orders.quantity > 0
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
              AND orders.auto_expire_date >= DATE(#{start_date}) - INTERVAL 9 MONTH
              AND orders.voided = 0
            INNER JOIN drug_order AS drug_order
              ON drug_order.order_id = orders.order_id
              AND drug_order.drug_inventory_id IN (#{primary_drug_query})
              AND drug_order.quantity > 0
            WHERE patient_program.program_id IN (SELECT program_id FROM program WHERE name = 'HIV Program')
              AND patient_program.patient_id NOT IN (
                SELECT person_id FROM obs
                WHERE concept_id IN (
                  SELECT concept_id FROM concept_name WHERE name LIKE 'Type of patient'
                ) AND value_coded IN (
                  SELECT concept_id FROM concept_name WHERE name LIKE 'External Consultation'
                ) AND voided = 0 AND (obs_datetime < DATE(#{end_date}) + INTERVAL 1 DAY)
                GROUP BY person_id
              )
          )
          GROUP BY patient_program.patient_id
        SQL
      end
    end
  end
end
