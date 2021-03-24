# frozen_string_literal: true

##
# TB Preventive Therapy indicators for ART cohort
module ARTService::Reports::Cohort::Tpt
  ##
  # Patients (re-)initiated on 3HP in current reporting period.
  #
  # Candidates for this indicator are patients who either have
  # had their first dispensation in the current reporting period
  # or patients who have restarted 3HP in the current reporting
  # period after breaking from the course for a period of at least
  # 9 months (3 quarters).
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
  # Patients (re-)initiated on IPT in current reporting period
  #
  # Has a similar definition to 3HP, please refer to 3HP docs
  # above.
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
      INNER JOIN orders AS orders
        ON orders.patient_id = cohort_patients.patient_id
        AND orders.order_type_id = (SELECT order_type_id FROM order_type WHERE name = 'Drug order' LIMIT 1)
        AND orders.start_date >= #{start_date}
        AND orders.start_date < DATE(#{end_date}) + INTERVAL 1 DAY
        AND orders.voided = 0
      INNER JOIN drug_order AS drug_orders
        ON drug_orders.order_id = orders.order_id
        AND drug_orders.drug_inventory_id IN (#{primary_drug_query})
        AND drug_orders.quantity > 0
      INNER JOIN encounter
        /* Ensure we are dealing with ART prescriptions (Treatment encounter) */
        ON encounter.encounter_id = orders.encounter_id
        AND encounter.encounter_type = (SELECT encounter_type_id FROM encounter_type WHERE name = 'Treatment' LIMIT 1)
        AND encounter.program_id = (SELECT program_id FROM program WHERE name = 'HIV Program' LIMIT 1)
        AND encounter.voided = 0
      WHERE cohort_patients.patient_id NOT IN (
        /* Filter out patients who received TPT before current reporting period */
        SELECT DISTINCT cohort_patients.patient_id
        FROM temp_earliest_start_date AS cohort_patients
        INNER JOIN orders
          ON orders.patient_id = cohort_patients.patient_id
          AND orders.order_type_id = (SELECT order_type_id FROM order_type WHERE name = 'Drug order' LIMIT 1)
          AND orders.start_date < #{start_date}
          /* DHA Recommendation: A break of 3 quarters is considered a re-initiation. */
          AND orders.auto_expire_date >= (DATE(#{start_date}) - INTERVAL 9 MONTH)
          AND orders.voided = 0
        INNER JOIN drug_order AS drug_orders
          ON drug_orders.order_id = orders.order_id
          AND drug_orders.drug_inventory_id IN (#{primary_drug_query})
          AND drug_orders.quantity > 0
        INNER JOIN encounter
          /* Ensure we are dealing with ART Prescriptions (Treatment encounter) */
          ON encounter.encounter_id = orders.encounter_id
          AND encounter.encounter_type = (SELECT encounter_type_id FROM encounter_type WHERE name = 'Treatment' LIMIT 1)
          AND encounter.program_id = (SELECT program_id FROM program WHERE name = 'HIV Program' LIMIT 1)
          AND encounter.voided = 0
      )
    SQL
  end
end
