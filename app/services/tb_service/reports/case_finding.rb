# frozen_string_literal: true

module TBService::Reports::CaseFinding
  class << self
    def new_pulmonary_clinically_diagnosed(start_date, end_date)
      query_init = new_patients_query.ref(start_date, end_date)
      query = query_init.with_clinical_pulmonary_tuberculosis(start_date, end_date)
      query.exclude_smear_positive(query_init, start_date, end_date)
    end

    def new_eptb(start_date, end_date)
      query = new_patients_query.ref(start_date, end_date)
      query.with_eptb_tuberculosis(start_date, end_date)
    end

    def new_mtb_detected_xpert(start_date, end_date)
      query = new_patients_query.ref(start_date, end_date)
      query.with_mtb_through_xpert(start_date, end_date)
    end

    def new_smear_positive(start_date, end_date)
      query = new_patients_query.ref(start_date, end_date)
      query.smear_positive(start_date, end_date)
    end

    def relapse_bacteriologically_confirmed(start_date, end_date)
      query = relapses_query.ref(start_date, end_date)
      query.bact_confirmed(start_date, end_date)
    end

    def relapse_clinical_pulmonary(start_date, end_date)
      query = relapses_query.ref(start_date, end_date)
      query.clinical_pulmonary(start_date, end_date)
    end

    def relapse_eptb(start_date, end_date)
      query = relapses_query.ref(start_date, end_date)
      query.eptb(start_date, end_date)
    end

    def treatment_failure_bacteriologically_confirmed(start_date, end_date)
      query = failures_query.ref(start_date, end_date)
      query.bact_confirmed(start_date, end_date)
    end

    def treatment_ltf_bacteriologically_confirmed(start_date, end_date)
      query = defaulters_query.ref(start_date, end_date)
      query.bact_confirmed(start_date, end_date)
    end

    def treatment_ltf_clinically_diagnosed_pulmonary(start_date, end_date)
      query = defaulters_query.ref(start_date, end_date)
      query.clinical_pulmonary(start_date, end_date)
    end

    def treatment_ltf_eptb(start_date, end_date)
      query = defaulters_query.ref(start_date, end_date)
      query.eptb(start_date, end_date)
    end

    def unknown_previous_treatment_history_pulmonary_clinic(start_date, end_date)
      query = tx_history_query.ref(start_date, end_date)
      query.pulmonary_diagnosis(start_date, end_date)
    end

    def other_previously_treated_bacteriologically_confirmed(start_date, end_date)
      query = other_tx_history_query.ref(start_date, end_date)
      query.bact_confirmed(start_date, end_date)
    end

    def other_previously_treated_clinical_pulmonary(start_date, end_date)
      query = other_tx_history_query.ref(start_date, end_date)
      query.clinical_pulmonary(start_date, end_date)
    end

    def other_previously_treated_eptb(start_date, end_date)
      query = other_tx_history_query.ref(start_date, end_date)
      query.eptb(start_date, end_date)
    end

    def unknown_previous_treatment_history_bacteriological(start_date, end_date)
      query = tx_history_query.ref(start_date, end_date)
      query.bact_confirmed(start_date, end_date)
    end

    def unknown_previous_treatment_history_eptb(start_date, end_date)
      query = tx_history_query.ref(start_date, end_date)
      query.eptb(start_date, end_date)
    end

    def patients_with_presumptive_tb_undergoing_bacteriological_examination(start_date, end_date)
      presumptives_query.undergoing_bacteriological_examination(start_date, end_date)
    end

    def patients_with_presumptive_tb_undergoing_bacteriological_examination_via_xpert(start_date, end_date)
      presumptives_query.via_xpert(start_date, end_date)
    end

    def patients_with_presumptive_tb_undergoing_bacteriological_examination_via_microscopy(start_date, end_date)
      presumptives_query.via_microscopy(start_date, end_date)
    end

    def patients_with_presumptive_tb_with_positive_bacteriological_examination(start_date, end_date)
      presumptives_query.with_positive_bacteriological_examination(start_date, end_date)
    end

    def patients_with_presumptive_tb_with_positive_bacteriological_examination_via_xpert(start_date, end_date)
      presumptives_query.via_xpert_pos(start_date, end_date)
    end

    def patients_with_presumptive_tb_with_positive_bacteriological_examination_via_microscopy(start_date, end_date)
      presumptives_query.via_microscopy_pos(start_date, end_date)
    end

    private

    def new_patients_query
      TBQueries::NewPatientsQuery.new
    end

    def relapses_query
      TBQueries::RelapsePatientsQuery.new
    end

    def tx_history_query
      TBQueries::UnknownTreatmentHistoryQuery.new
    end

    def other_tx_history_query
      TBQueries::OtherTreatmentHistoryQuery.new
    end

    def presumptives_query
      TBQueries::PresumptivesQuery.new
    end

    def defaulters_query
      TBQueries::DefaultersQuery.new
    end

    def failures_query
      TBQueries::FailuresQuery.new
    end
  end
end
