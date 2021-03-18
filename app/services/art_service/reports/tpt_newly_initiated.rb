# frozen_string_literal: true

module ARTService
  module Reports
    ##
    # Patients newly initiated on TPT disaggregated by regimen type and age group
    class TptNewlyInitiated
      attr_reader :start_date, :end_date

      def initialize(start_date:, end_date:, **_kwargs)
        @start_date = ActiveRecord::Base.connection.quote(start_date)
        @end_date = ActiveRecord::Base.connection.quote(end_date)
      end

      def find_report
        report = init_report

        load_patients_into_report(report, newly_initiated_on_3hp)
        load_patients_into_report(report, newly_initiated_on_6h)

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
        AGE_GROUPS.each_with_object({}) { |age_group, report| report[age_group] = [] }
      end

      def load_patients_into_report(report, patients)
        patients.each do |patient|
          age_group = patient.delete('age_group')

          report[age_group] << patient
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
                 cohort_disaggregated_age_group(person.birthdate, CURRENT_DATE()) AS age_group,
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
          INNER JOIN orders AS primary_drug_order
            ON primary_drug_order.encounter_id = prescription_encounter.encounter_id
            AND primary_drug_order.order_type_id = (SELECT order_type_id FROM order_type WHERE name = 'Drug order' LIMIT 1)
            AND primary_drug_order.start_date >= #{start_date}
            AND primary_drug_order.start_date < DATE(#{end_date}) + INTERVAL 1 DAY
            AND primary_drug_order.voided = 0
          INNER JOIN drug_order AS primary_drug_order_drug
            ON primary_drug_order_drug.order_id = primary_drug_order.order_id
            AND primary_drug_order_drug.drug_inventory_id IN (#{primary_drug_query})
            AND primary_drug_order_drug.quantity > 0  /* This implies that a dispensation was made */
          /* Ensure that the primary drug dispensed above was prescribed together with Isoniazid (INH) */
          INNER JOIN orders AS inh_order
            ON inh_order.encounter_id = prescription_encounter.encounter_id
            AND inh_order.order_type_id = (SELECT order_type_id FROM order_type WHERE name = 'Drug order' LIMIT 1)
            AND inh_order.start_date >= #{start_date}
            AND inh_order.start_date < DATE(#{end_date}) + INTERVAL 1 DAY
            AND inh_order.voided = 0
          INNER JOIN drug_order AS inh_drug_order
            ON inh_drug_order.order_id = inh_order.order_id
            AND inh_drug_order.drug_inventory_id IN (SELECT DISTINCT drug_id FROM drug INNER JOIN concept_name USING (concept_id) WHERE concept_name.name = 'Isoniazid')
            AND inh_drug_order.quantity > 0 /* A dispensation was made */
          WHERE patient_program.patient_id NOT IN (
            /* Filter out patients who received TPT before current reporting period */
            SELECT DISTINCT patient_program.patient_id
            FROM patient_program
            INNER JOIN encounter AS prescription_encounter
              ON prescription_encounter.patient_id = patient_program.patient_id
              AND prescription_encounter.encounter_type IN (SELECT encounter_type_id FROM encounter_type WHERE name = 'Treatment')
              AND prescription_encounter.program_id = (SELECT program_id FROM program WHERE name = 'HIV Program' LIMIT 1)
              AND prescription_encounter.voided = 0
            INNER JOIN orders AS primary_drug_order
              ON primary_drug_order.encounter_id = prescription_encounter.encounter_id
              AND primary_drug_order.order_type_id = (SELECT order_type_id FROM order_type WHERE name = 'Drug order' LIMIT 1)
              AND primary_drug_order.start_date < #{start_date}
              AND primary_drug_order.voided = 0
            INNER JOIN drug_order AS rfp_drug_order
              ON rfp_drug_order.order_id = primary_drug_order.order_id
              AND rfp_drug_order.drug_inventory_id IN (#{primary_drug_query})
              AND rfp_drug_order.quantity > 0
            INNER JOIN orders AS inh_order
              ON inh_order.encounter_id = prescription_encounter.encounter_id
              AND inh_order.order_type_id IN (SELECT order_type_id FROM order_type WHERE name = 'Drug order')
              AND inh_order.start_date < #{start_date}
              AND inh_order.voided = 0
            INNER JOIN drug_order AS inh_drug_order
              ON inh_drug_order.order_id = inh_order.order_id
              AND inh_drug_order.drug_inventory_id IN (SELECT DISTINCT drug_id FROM drug INNER JOIN concept_name USING (concept_id) WHERE concept_name.name = 'Isoniazid')
              AND inh_drug_order.quantity > 0
            WHERE patient_program.program_id IN (SELECT program_id FROM program WHERE name = 'HIV Program')
          )
          GROUP BY patient_program.patient_id
        SQL
      end
    end
  end
end
