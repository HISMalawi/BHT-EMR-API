# frozen_string_literal: true

module TBService::Reports::Quarterly
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

    def retreatment_excluding_relapse(start_date, end_date)
      retreatment_patients_query.ref(start_date, end_date)
    end

    def hiv_positive_new_and_relapse(start_date, end_date)
      new_cases = new_patients_query.ref(start_date, end_date)
      relapses = relapses_query.ref(start_date, end_date)

      unless new_cases.empty? && relapses.empty?
        all = Patient.where(patient_id: (new_cases + relapses))
        query = hiv_result_query.new(all).ref
        query.positive
      end
    end

    def children_aged_zero_to_four(start_date, end_date)
      query = cases_query.ref(start_date, end_date)
      ipt_patients = ipt_candidate_query.ref(start_date, end_date)
      query.age_range(0, 4).merge(query.where.not(patient_id: ipt_patients.map(&:patient_id)))
    end

    def children_aged_five_to_fourteen(start_date, end_date)
      query = cases_query.ref(start_date, end_date)
      query.age_range(5, 14)
    end

    private

    def cases_query
      TBQueries::CasesQuery.new
    end

    def relapses_query
      TBQueries::RelapsePatientsQuery.new
    end

    def new_patients_query
      TBQueries::NewPatientsQuery.new
    end

    def hiv_result_query
      TBQueries::HivResultQuery
    end

    def retreatment_patients_query
      TBQueries::RetreatmentPatientsQuery.new
    end

    def ipt_candidate_query
      TBQueries::IptCandidatesQuery.new
    end
  end
end
