module ARTService::Reports::MasterCard
  class PediatricCardStruct < MastercardStruct
    def indicators
      [
        agrees_to_followup,
        birth_cohort,
        load_ped_status_on_enrollment,
        transfer_in_date,
        load_enrollment_age_and_duration,
      ]
    end

    def birth_cohort
      {
        birth_cohort_month: patient.person.birthdate.strftime("%b"),
        birth_cohort_year: patient.person.birthdate.strftime("%Y"),
      }
    end

    def load_ped_status_on_enrollment
      {
        mother_status: "Ukn",
        mother_art_reg_no: "Ukn",
        mother_art_start_date: "Ukn",
      }
    end

    def load_enrollment_age_and_duration
      value_drug = Drug.find_by(drug_id: 732)

      drugs = dispensation_service.dispensations(patient.id)
        .select { |q| q["value_drug"].to_i == value_drug.id }

      sorted = drugs.sort! { |a, b| a["obs_datetime"] <=> b["obs_datetime"] }

      enrollment_duration(sorted, value_drug.name).merge(enrollment_age(sorted, value_drug.name))
    end

    def enrollment_duration(drugs, drug_name)
      # get first and last obs
      return { enrollment_duration_2p: "" } if drugs.blank?
      oldest_date = drugs.first["obs_datetime"]
      discontinued_date = drugs.last["obs_datetime"]
      { enrollment_duration_2p: (oldest_date.to_date - discontinued_date.to_date).to_i }
    end

    def enrollment_age(drugs, drug_name)
      { enrollment_age_2p: (1.year.ago.to_date - patient.person.birthdate.to_date).to_i }
    end

    def dispensation_service
      DispensationService
    end
  end
end
