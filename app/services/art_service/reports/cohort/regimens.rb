# frozen_string_literal: true

module ArtService
  module Reports
    module Cohort
      # This module is responsible for generating the regimen report
      module Regimens
        # rubocop:disable Metrics/MethodLength
        def self.patient_regimens
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT prescriptions.patient_id, regimens.name AS regimen_category, prescriptions.drugs, prescriptions.prescription_date
            FROM (
              SELECT tcm.patient_id, GROUP_CONCAT(DISTINCT(tcm.drug_id) ORDER BY tcm.drug_id ASC) AS drugs, DATE(tcm.start_date) prescription_date
              FROM temp_current_medication tcm
              INNER JOIN temp_patient_outcomes AS outcomes ON outcomes.patient_id = tcm.patient_id AND outcomes.moh_cum_outcome = 'On antiretrovirals'
              GROUP BY tcm.patient_id
            ) AS prescriptions
            LEFT JOIN (
              SELECT GROUP_CONCAT(drug.drug_id ORDER BY drug.drug_id ASC) AS drugs, regimen_name.name AS name
              FROM moh_regimen_combination AS combo
              INNER JOIN moh_regimen_combination_drug AS drug USING (regimen_combination_id)
              INNER JOIN moh_regimen_name AS regimen_name USING (regimen_name_id)
              GROUP BY combo.regimen_combination_id
            ) AS regimens ON regimens.drugs = prescriptions.drugs
          SQL
        end
        # rubocop:enable Metrics/MethodLength

        def self.arv_drugs_concept_set
          @arv_drugs_concept_set ||= ConceptSet.where(set: Concept.find_by_name('Antiretroviral drugs'))
                                               .select(:concept_id)
        end
      end
    end
  end
end
