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
    processed_tpt_clients.select { |patient| patient_on_3hp?(patient) }
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
    processed_tpt_clients.reject { |patient| patient_on_3hp?(patient) }
  end

  private

  def patient_on_3hp?(patient)
    drug_concepts = patient['drug_concepts'].split(',').collect(&:to_i)
    (drug_concepts & [rifapentine_concept.concept_id, three_hp_concept&.concept_id]).any?
  end

  def rifapentine_concept
    @rifapentine_concept ||= ConceptName.find_by!(name: 'Rifapentine')
  end

  def three_hp_concept
    @three_hp_concept ||= ConceptName.find_by!(name: 'Isoniazid/Rifapentine')
  end

  def processed_tpt_clients
    @processed_tpt_clients ||= process_tpt_clients
  end

  def process_tpt_clients
    patients = []
    newly_initiated_on_tpt.each do |patient|
      course = patient['course'].match(/3HP/) ? '3HP' : 'IPT'
      if patient['transfer_course'].blank? && patient['last_course'].blank?
        patients << patient
      elsif patient['transfer_course'].present? && patient['last_course'].blank?
        patients << patient if patient['months_since_tpt_transfer'].to_i >= (course == '3HP' ? 1 : 2)
      elsif patient['transfer_course'].blank? && patient['last_course'].present?
        patients << patient if patient['months_since_last_tpt'].to_i >= (course == '3HP' ? 1 : 2)
      elsif patient['last_tpt_end_date'].to_date >= patient['transfer_end_date'].to_date
        patients << patient if patient['months_since_last_tpt'].to_i >= (course == '3HP' ? 1 : 2)
      elsif patient['last_tpt_end_date'].to_date < patient['transfer_end_date'].to_date
        patients << patient if patient['months_since_tpt_transfer'].to_i >= (course == '3HP' ? 1 : 2)
      end
    end
    patients
  end

  def newly_initiated_on_tpt
    start_date = ActiveRecord::Base.connection.quote(@start_date)
    end_date = ActiveRecord::Base.connection.quote(@end_date)

    @newly_initiated_on_tpt ||= ActiveRecord::Base.connection.select_all <<~SQL
      SELECT
        cohort_patients.patient_id,
        cohort_patients.earliest_start_date,
        MIN(orders.start_date )as tpt_start_date,
        GROUP_CONCAT(DISTINCT orders.concept_id SEPARATOR ',') AS drug_concepts,
        CASE
          WHEN count(distinct(orders.concept_id)) > 1 THEN '3HP old'
          WHEN orders.concept_id = #{three_hp_concept.concept_id} THEN '3HP new'
          ELSE '6H'
        END AS course,
        tpt_transfer_in_obs.value_datetime AS tpt_initial_start_date,
        CASE
          WHEN tpt_transfer_in_obs.concept_id IS NULL THEN NULL
          WHEN count(distinct(tpt_transfer_in_obs.concept_id)) > 1 THEN '3HP old'
          WHEN tpt_transfer_in_obs.concept_id = #{three_hp_concept.concept_id} THEN '3HP new'
          ELSE '6H'
        END AS transfer_course,
        tpt_transfer_in_obs.obs_datetime AS transfer_end_date,
        tpt_transfer_in_obs.value_numeric AS transfer_amount,
        TIMESTAMPDIFF(MONTH, tpt_transfer_in_obs.obs_datetime, MIN(orders.start_date)) AS months_since_tpt_transfer,
        TIMESTAMPDIFF(MONTH, last_tpt_prescription.auto_expire_date, MIN(orders.start_date)) AS months_since_last_tpt,
        last_tpt_prescription.course AS last_course,
        last_tpt_prescription.start_date AS last_tpt_start_date,
        last_tpt_prescription.auto_expire_date AS last_tpt_end_date
      FROM temp_earliest_start_date AS cohort_patients
      INNER JOIN orders
        ON orders.patient_id = cohort_patients.patient_id
        AND orders.order_type_id = (SELECT order_type_id FROM order_type WHERE name = 'Drug order' LIMIT 1)
        AND orders.start_date >= #{start_date}
        AND orders.start_date < DATE(#{end_date}) + INTERVAL 1 DAY
        AND orders.voided = 0
      INNER JOIN concept_name AS tpt_drug_concepts
        ON tpt_drug_concepts.concept_id = orders.concept_id
        AND tpt_drug_concepts.name IN ('Rifapentine', 'Isoniazid', 'Isoniazid/Rifapentine')
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
      LEFT JOIN obs tpt_transfer_in_obs
        ON tpt_transfer_in_obs.person_id = orders.patient_id
        AND tpt_transfer_in_obs.concept_id = #{ConceptName.find_by_name('TPT Drugs Received').concept_id}
        AND tpt_transfer_in_obs.voided = 0
        AND tpt_transfer_in_obs.value_drug IN (SELECT drug_id FROM drug WHERE concept_id IN (SELECT concept_id FROM concept_name WHERE name IN ('Rifapentine', 'Isoniazid', 'Isoniazid/Rifapentine')))
      LEFT JOIN (
        SELECT
          o.patient_id,
          MAX(o.start_date) AS start_date,
          MAX(o.auto_expire_date) AS auto_expire_date,
          CASE
            WHEN count(distinct(o.concept_id)) > 1 THEN '3HP old'
            WHEN o.concept_id = #{three_hp_concept.concept_id} THEN '3HP new'
            ELSE '6H'
          END AS course
        FROM temp_earliest_start_date
        INNER JOIN orders o ON o.patient_id = temp_earliest_start_date.patient_id
        INNER JOIN concept_name AS tpt_drug_concepts ON tpt_drug_concepts.concept_id = o.concept_id AND tpt_drug_concepts.name IN ('Rifapentine', 'Isoniazid', 'Isoniazid/Rifapentine') AND tpt_drug_concepts.voided = 0
        INNER JOIN drug_order AS drug_orders ON drug_orders.order_id = o.order_id AND drug_orders.quantity > 0
        INNER JOIN encounter ON encounter.encounter_id = o.encounter_id AND encounter.encounter_type = (SELECT encounter_type_id FROM encounter_type WHERE name = 'Treatment' LIMIT 1) AND encounter.program_id = (SELECT program_id FROM program WHERE name = 'HIV Program' LIMIT 1) AND encounter.voided = 0
        WHERE o.voided = 0
        AND o.start_date < #{start_date}
        GROUP BY o.patient_id
      ) AS last_tpt_prescription ON last_tpt_prescription.patient_id = orders.patient_id
      /** WHERE cohort_patients.patient_id NOT IN (
        -- Filter out patients who received TPT before current reporting period
        SELECT DISTINCT cohort_patients.patient_id
        FROM temp_earliest_start_date AS cohort_patients
        INNER JOIN orders
          ON orders.patient_id = cohort_patients.patient_id
          AND orders.order_type_id = (SELECT order_type_id FROM order_type WHERE name = 'Drug order' LIMIT 1)
          AND orders.start_date < #{start_date}
          /* DHA Recommendation: A break of 3 quarters is considered a re-initiation.
          AND orders.auto_expire_date >= (DATE(#{start_date}) - INTERVAL 9 MONTH)
          AND orders.voided = 0
        INNER JOIN concept_name AS tpt_drug_concepts
          ON tpt_drug_concepts.concept_id = orders.concept_id
          AND tpt_drug_concepts.name IN ('Rifapentine', 'Isoniazid', 'Isoniazid/Rifapentine')
          AND tpt_drug_concepts.voided = 0
        INNER JOIN drug_order AS drug_orders
          ON drug_orders.order_id = orders.order_id
          AND drug_orders.quantity > 0
        INNER JOIN encounter
          -- Ensure we are dealing with ART Prescriptions (Treatment encounter)
          ON encounter.encounter_id = orders.encounter_id
          AND encounter.encounter_type = (SELECT encounter_type_id FROM encounter_type WHERE name = 'Treatment' LIMIT 1)
          AND encounter.program_id = (SELECT program_id FROM program WHERE name = 'HIV Program' LIMIT 1)
          AND encounter.voided = 0
      ) **/
      GROUP BY cohort_patients.patient_id
    SQL
  end
end
