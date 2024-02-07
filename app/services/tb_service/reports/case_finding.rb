# frozen_string_literal: true

module TBService::Reports::CaseFinding
  class << self

    AGE_GROUPS = {
      '0-4' => [0, 4],
      '5-14' => [5, 14],
      '15-24' => [15, 24],
      '25-34' => [25, 34],
      '35-44' => [35, 44],
      '45-54' => [45, 54],
      '55-64' => [55, 64],
      '65+' => [65, 200]
    }.freeze

    def report_format(indicator)
      format_ = {
        indicator: indicator
      }
      AGE_GROUPS.each_key do |k|
        format_[k] = {
          male: [],
          female: []
        }
      end
      format_
    end

    def format_report(indicator:, report_data:)
      data = report_format(indicator)
      report_data.each do |patient|
        process_patient(patient, data)
      end
      data
    end

    def process_patient(patient, data)
      age = patient.age
      gender = patient.gender == 'M' ? :male : :female
      age_group = AGE_GROUPS.keys.find { |k| age.between?(*AGE_GROUPS[k]) }
      data[age_group][gender] << patient.id
    end

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
      TBService::TBQueries::NewPatientsQuery.new
    end

    def relapses_query
      TBService::TBQueries::RelapsePatientsQuery.new
    end

    def tx_history_query
      TBService::TBQueries::UnknownTreatmentHistoryQuery.new
    end

    def other_tx_history_query
      TBService::TBQueries::OtherTreatmentHistoryQuery.new
    end

    def presumptives_query
      TBService::TBQueries::PresumptivesQuery.new
    end

    def defaulters_query
      TBService::TBQueries::DefaultersQuery.new
    end

    def failures_query
      TBService::TBQueries::FailuresQuery.new
    end
  end
end
