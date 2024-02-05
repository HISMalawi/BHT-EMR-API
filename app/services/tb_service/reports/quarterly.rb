# frozen_string_literal: true

module TBService::Reports::Quarterly
  class << self

    def report_format(indicator)
      {
        indicator: indicator,
        cases: [],
        cured: [],
        complete: [],
        failed: [],
        died: [],
        lost: [],
        ne: []
      }
    end

    def format_report(indicator:, report_data:)
      data = report_format(indicator)
      program = Program.find_by_name('TB PROGRAM')
      report_data.each do |patient|
        process_patient(patient, data, program)
      end
      data
    end

    private

    def process_patient(patient, data, program)
      data[:cases] << patient.id
      outcome = patient.outcome(program, Date.today)
      out_name = outcome.name&.parameterize&.underscore
      case out_name
      when nil
        data[:ne] << patient.id
      when 'cured', 'complete', 'failed', 'died', 'lost'
        data[out_name] ||= []
        data[out_name] << patient.id
      end
    end

    def patient_ids(data)
      data.map(&:patient_id)
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
      TBService::TBQueries::CasesQuery.new
    end

    def relapses_query
      TBService::TBQueries::RelapsePatientsQuery.new
    end

    def new_patients_query
      TBService::TBQueries::NewPatientsQuery.new
    end

    def hiv_result_query
      TBService::TBQueries::HivResultQuery
    end

    def retreatment_patients_query
      TBService::TBQueries::RetreatmentPatientsQuery.new
    end

    def ipt_candidate_query
      TBService::TBQueries::IptCandidatesQuery.new
    end
  end
end
