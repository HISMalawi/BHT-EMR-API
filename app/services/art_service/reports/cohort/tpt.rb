# frozen_string_literal: true

##
# TB Preventive Therapy indicators for ART cohort
module ARTService::Reports::Cohort::Tpt
  ##
  # Patients initiated on 3HP in current reporting period.
  def self.newly_initiated_on_3hp(start_date, end_date)
    newly_initiated_on_tpt start_date, end_date, <<~SQL
      SELECT DISTINCT drug_id
      FROM drug
      INNER JOIN concept_name
        USING (concept_id)
      WHERE concept_name.name = 'Rifapentine'
    SQL
  end

  ##
  # Patients initiated on IPT in current reporting period
  def self.newly_initiated_on_ipt(start_date, end_date)
    newly_initiated_on_tpt start_date, end_date, <<~SQL
      SELECT DISTINCT drug_id
      FROM drug
      INNER JOIN concept_name
        USING (concept_id)
      WHERE concept_name.name = 'Pyridoxine'
    SQL
  end

  def self.newly_initiated_on_tpt(start_date, end_date, primary_drug_query)
    start_date = ActiveRecord::Base.connection.quote(start_date)
    end_date = ActiveRecord::Base.connection.quote(end_date)

    ActiveRecord::Base.connection.select_all <<~SQL
      SELECT DISTINCT cohort_patients.patient_id
      FROM temp_earliest_start_date AS cohort_patients
      INNER JOIN orders AS rfp_orders
        ON rfp_orders.patient_id = cohort_patients.patient_id
        AND rfp_orders.order_type_id = (SELECT order_type_id FROM order_type WHERE name = 'Drug order' LIMIT 1)
        AND rfp_orders.start_date BETWEEN #{start_date} AND #{end_date}
        AND rfp_orders.voided = 0
      INNER JOIN drug_order AS rfp_drug_orders
        ON rfp_drug_orders.order_id = rfp_orders.order_id
        AND rfp_drug_orders.drug_inventory_id IN (#{primary_drug_query})
        AND rfp_drug_orders.quantity > 0
      INNER JOIN orders AS inh_orders
        ON inh_orders.patient_id = cohort_patients.patient_id
        AND inh_orders.order_type_id = (SELECT order_type_id FROM order_type WHERE name = 'Drug order' LIMIT 1)
        AND inh_orders.start_date BETWEEN #{start_date} AND #{end_date}
        AND inh_orders.voided = 0
      INNER JOIN drug_order AS inh_drug_orders
        ON inh_drug_orders.order_id = inh_orders.order_id
        AND inh_drug_orders.drug_inventory_id IN (SELECT DISTINCT drug_id FROM drug INNER JOIN concept_name USING (concept_id) WHERE concept_name.name = 'Isoniazid')
        AND inh_drug_orders.quantity > 0
      INNER JOIN encounter
        /* Ensure both drugs are under the same treatment encounter. */
        ON encounter.encounter_id = rfp_orders.encounter_id
        AND encounter.encounter_id = inh_orders.encounter_id
        AND encounter.program_id = (SELECT program_id FROM program WHERE name = 'HIV Program' LIMIT 1)
        AND encounter.voided = 0
      WHERE cohort_patients.patient_id NOT IN (
        /* Filter out patients who received Rifapentine before current reporting period */
        SELECT DISTINCT cohort_patients.patient_id
        FROM temp_earliest_start_date AS cohort_patients
        INNER JOIN orders AS rfp_orders
          ON rfp_orders.patient_id = cohort_patients.patient_id
          AND rfp_orders.order_type_id = (SELECT order_type_id FROM order_type WHERE name = 'Drug order' LIMIT 1)
          AND rfp_orders.start_date < #{start_date}
          AND rfp_orders.voided = 0
        INNER JOIN drug_order AS rfp_drug_orders
          ON rfp_drug_orders.order_id = rfp_orders.order_id
          AND rfp_drug_orders.drug_inventory_id IN (#{primary_drug_query})
          AND rfp_drug_orders.quantity > 0
        INNER JOIN orders AS inh_orders
          ON inh_orders.patient_id = cohort_patients.patient_id
          AND inh_orders.order_type_id = (SELECT order_type_id FROM order_type WHERE name = 'Drug order' LIMIT 1)
          AND inh_orders.start_date < #{start_date}
          AND inh_orders.voided = 0
        INNER JOIN drug_order AS inh_drug_orders
          ON inh_drug_orders.order_id = inh_orders.order_id
          AND inh_drug_orders.drug_inventory_id IN (SELECT DISTINCT drug_id FROM drug INNER JOIN concept_name USING (concept_id) WHERE concept_name.name = 'Isoniazid')
          AND inh_drug_orders.quantity > 0
        INNER JOIN encounter
          /* Ensure both drugs are under the same dispensation encounter. */
          ON encounter.encounter_id = rfp_orders.encounter_id
          AND encounter.encounter_id = inh_orders.encounter_id
          AND encounter.program_id = (SELECT program_id FROM program WHERE name = 'HIV Program' LIMIT 1)
          AND encounter.voided = 0
      )
    SQL
  end
end
