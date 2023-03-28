module ARTService::Reports::MasterCard
  class PatientStruct < MastercardStruct
    def indicators
      [
        load_baseline_lab_results,
        agrees_to_followup,
        load_confimatory_hiv_test,
        load_followup_testing,
        load_art_initiation,
        transfer_in_date,
      ]
    end

    def load_followup_testing
      lab_results = {}
      { cd4: "CD4 count", bp: "Blood pressure", fbs: "FBS" }
        .each do |key, value|
        results = patient_visit.lab_result(value)
        lab_results[key] = ""

        next if results.blank?

        # remove the result on the first visit
        results.delete_at(0)
        lab_results[key] = results
      end
      { followup_testing: lab_results }
    end

    def load_baseline_lab_results
      lab_results = {}
      { cd4: "CD4 count", tb_xpert: "Genexpert", urine_lam: "Urine Lam", crag: "CrAg" }
        .each do |key, value|
        results = patient_visit.lab_result(value)
        lab_results[key] = ""

        next if results.blank?

        lab_results[key] = results.first[:result]

        lab_results["#{key}_date"] = results.first[:result_date]
      end
      lab_results
    end

    def load_art_initiation
      {
        art_number: patient_history.arv_number,
        height: patient_history.initial_height,
        weight: patient_history.initial_weight,
        hiv_related_diseases: patient_history.who_clinical_conditions_list.join(", "),
        who_stage: patient_who_stage,
        tb_status_at_art_initiation: calc_tb_status_at_art_initiation,
        ks: patient_history.ks,
        preg_or_breastfeeding: pregnancy_status_on_first_visit,
      }
    end

    def load_confimatory_hiv_test
      {
        facility: patient_history.initial_observation("Confirmatory HIV test location")&.answer_string || "UNKNOWN",
        confimatory_test_type: patient_history.initial_observation("Confirmatory HIV test type")&.answer_string || "UNKNOWN",
        confimatory_test_date: patient_history.initial_observation("Confirmatory HIV test date")&.value_datetime.to_s.to_date || "UNKNOWN",
        link_id: patient_history.initial_observation("HTC serial number")&.answer_string || "UNKNOWN",
      }
    end

    def patient_who_stage
      Patient.find_by_sql("SELECT patient_who_stage(#{patient.id}) as who_stage").first.who_stage
    end

    def calc_tb_status_at_art_initiation
      obs = initial_observation("TB Status")&.value_answer
      return "N" unless obs
      return "Y" if obs == "Confirmed TB Not on treatment"
      return "N"
    end

    def pregnancy_status_on_first_visit
      pregnant_concept = concept("Is Patient Pregnant?")
      obs = initial_observation(pregnant_concept)
      return "N" unless obs
      is_pregnant = obs.value_coded == concept("Yes").concept_id
      if is_pregnant
        bf_obs = initial_observation(concept("Is Patient Breastfeeding?"))
        return "Y" unless bf_obs
        return bf_obs.value_coded == concept("Yes").concept_id
      end
      return is_pregnant ? "Y" : "N"
    end
  end
end
