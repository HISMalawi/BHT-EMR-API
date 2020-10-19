# frozen_string_literal: true

module ARTService::Reports::Cohort::Regimens
  def self.patient_regimens(date)
    date = ActiveRecord::Base.connection.quote(date)

    ActiveRecord::Base.connection.select_all <<~SQL
      SELECT prescriptions.patient_id,
             regimens.name AS regimen_category,
             prescriptions.drugs,
             prescriptions.prescription_date
      FROM (
        SELECT orders.patient_id,
               GROUP_CONCAT(DISTINCT(drug_order.drug_inventory_id)
                                     ORDER BY drug_order.drug_inventory_id ASC) AS drugs,
               recent_prescription.prescription_date
        FROM temp_patient_outcomes AS outcomes
        INNER JOIN orders
          ON orders.patient_id = outcomes.patient_id
          AND orders.concept_id IN (#{arv_drugs_concept_set.to_sql})
          AND orders.voided = 0
        INNER JOIN drug_order
          ON drug_order.order_id = orders.order_id AND drug_order.quantity > 0
        /* Only select drugs prescribed on the last prescription day */
        INNER JOIN (
          SELECT patient_id, DATE(MAX(start_date)) AS prescription_date
          FROM orders
          INNER JOIN drug_order
            ON drug_order.order_id = orders.order_id
            AND drug_order.quantity > 0
          WHERE orders.voided = 0
            AND orders.concept_id IN (#{arv_drugs_concept_set.to_sql})
            AND orders.start_date < (DATE(#{date}) + INTERVAL 1 DAY)
            AND orders.patient_id IN (
              SELECT patient_id FROM temp_patient_outcomes WHERE cum_outcome = 'On antiretrovirals'
            )
          GROUP BY orders.patient_id
        ) AS recent_prescription
          ON recent_prescription.patient_id = orders.patient_id
          AND orders.start_date
            BETWEEN recent_prescription.prescription_date
            AND (recent_prescription.prescription_date + INTERVAL 1 DAY)
        GROUP BY orders.patient_id
      ) AS prescriptions
      LEFT JOIN (
        SELECT GROUP_CONCAT(drug.drug_id ORDER BY drug.drug_id ASC) AS drugs,
              regimen_name.name AS name
        FROM moh_regimen_combination AS combo
          INNER JOIN moh_regimen_combination_drug AS drug USING (regimen_combination_id)
          INNER JOIN moh_regimen_name AS regimen_name USING (regimen_name_id)
        GROUP BY combo.regimen_combination_id
      ) AS regimens
        ON regimens.drugs = prescriptions.drugs
    SQL
  end

  def self.arv_drugs_concept_set
    @arv_drugs_concept_set ||= ConceptSet.where(set: Concept.find_by_name('Antiretroviral drugs'))
                                         .select(:concept_id)
  end
end
