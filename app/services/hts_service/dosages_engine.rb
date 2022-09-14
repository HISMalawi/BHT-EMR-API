# frozen_string_literal: true

module ARTService
  module DosagesEngine
    class << self
      ##
      # Returns dose for the given drug based on patient's weight on the given date
      def find_drug_dose(drug_id, patient_id, date)
        weight_obs = patients_engine.find_patient_recent_weight(patient_id, date)

        weight = weight_obs&.value_numeric || weight_obs&.value_text
        raise InvalidParameterError, "Patient doesn't have any weight recorded on or before given date" unless weight

        ingredient = MohRegimenIngredient.where(drug_inventory_id: drug_id)
                                         .where('min_weight <= :weight AND max_weight >= :weight', weight: weight)
                                         .includes(:dose)
                                         .group(:drug_inventory_id)
                                         .first
        raise InvalidParameterError, "Drug ##{drug_id} dose for weight #{weight} not found" unless ingredient

        {
          am: ingredient.dose.am,
          pm: ingredient.dose.pm,
          noon: 0,
          weight: { value: weight, date_recorded: weight_obs.obs_datetime }
        }
      end

      private

      def patients_engine
        ARTService::PatientsEngine.new
      end
    end
  end
end
