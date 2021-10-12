# frozen_string_literal: true

##
# TB Preventive Therapy indicators for ART cohort
class ARTService::Reports::Cohort::Tpt
  def initialize(start_date, end_date)
    @start_date = start_date
    @end_date = end_date
  end

  ##
  # Patients (re-)initiated on 3HP in current reporting period.
  #
  # Candidates for this indicator are patients who either have
  # had their first dispensation in the current reporting period
  # or patients who have restarted 3HP in the current reporting
  # period after breaking from the course for a period of at least
  # 9 months (3 quarters).
  def newly_initiated_on_3hp
    # newly_initiated_on_tpt(start_date, end_date).each_with_object([]) do |patient, patients|
    #   patients << patient['patient_id'] unless patient_on_3hp?(patient)
    # end
    newly_initiated_on_tpt.select { |patient| patient_on_3hp?(patient) }
  end

  ##
  # Patients (re-)initiated on IPT in current reporting period
  #
  # Has a similar definition to 3HP, please refer to 3HP docs
  # above.
  def newly_initiated_on_ipt
    # newly_initiated_on_tpt(start_date, end_date).each_with_object([]) do |patient, patients|
    #   patients << patient['patient_id'] if patient_on_3hp?(patient)
    # end
    newly_initiated_on_tpt.reject { |patient| patient_on_3hp?(patient) }
  end

  private

  def patient_on_3hp?(patient)
    patient['drug_concepts'].split(',').collect(&:to_i).include?(rifapentine_concept.concept_id)
  end

  def rifapentine_concept
    @rifapentine_concept ||= ConceptName.find_by!(name: 'Rifapentine')
  end

  def newly_initiated_on_tpt
    start_date = ActiveRecord::Base.connection.quote(@start_date)
    end_date = ActiveRecord::Base.connection.quote(@end_date)

    @newly_initiated_on_tpt ||= ActiveRecord::Base.connection.select_all <<~SQL
      SELECT cohort_patients.patient_id,
             GROUP_CONCAT(DISTINCT orders.concept_id SEPARATOR ',') AS drug_concepts
      FROM temp_earliest_start_date AS cohort_patients
      INNER JOIN orders
        ON orders.patient_id = cohort_patients.patient_id
        AND orders.order_type_id = (SELECT order_type_id FROM order_type WHERE name = 'Drug order' LIMIT 1)
        AND orders.start_date >= #{start_date}
        AND orders.start_date < DATE(#{end_date}) + INTERVAL 1 DAY
        AND orders.voided = 0
      INNER JOIN concept_name AS tpt_drug_concepts
        ON tpt_drug_concepts.concept_id = orders.concept_id
        AND tpt_drug_concepts.name IN ('Rifapentine', 'Isoniazid')
        AND tpt_drug_concepts.voided = 0
      INNER JOIN drug_order AS drug_orders
        ON drug_orders.order_id = orders.order_id
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
        INNER JOIN concept_name AS tpt_drug_concepts
          ON tpt_drug_concepts.concept_id = orders.concept_id
          AND tpt_drug_concepts.name IN ('Rifapentine', 'Isoniazid')
          AND tpt_drug_concepts.voided = 0
        INNER JOIN drug_order AS drug_orders
          ON drug_orders.order_id = orders.order_id
          AND drug_orders.quantity > 0
        INNER JOIN encounter
          /* Ensure we are dealing with ART Prescriptions (Treatment encounter) */
          ON encounter.encounter_id = orders.encounter_id
          AND encounter.encounter_type = (SELECT encounter_type_id FROM encounter_type WHERE name = 'Treatment' LIMIT 1)
          AND encounter.program_id = (SELECT program_id FROM program WHERE name = 'HIV Program' LIMIT 1)
          AND encounter.voided = 0
      )
      GROUP BY cohort_patients.patient_id
    SQL
  end
end
