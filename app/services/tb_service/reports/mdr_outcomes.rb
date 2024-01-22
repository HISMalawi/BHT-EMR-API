# frozen_string_literal: true

module TBService::Reports::MdrOutcomes
  class << self

    def total_cohort_cases_started(start_date, end_date)
        mdr_patient_query.ref(start_date, end_date)
    end

    def cured(start_date, end_date)
      to_result('Patient cured', start_date, end_date)
    end

    def completed(start_date, end_date)
      to_result('Treatment complete', start_date, end_date)
    end

    def died(start_date, end_date)
      to_result('Patient died', start_date, end_date)
    end

    def failed(start_date, end_date)
      to_result('Regimen failure', start_date, end_date)
    end

    private

    def to_result(outcome, start_date, end_date)
      query = patient_outcome_query.ref(start_date, end_date).distinct
      patients = query.present? ? query.map(&:patient_id) : []
      patient_outcome_query.outcome(outcome, patients, start_date, end_date)
    end

    def patient_outcome_query
      TBQueries::MdrOutcomeQuery.new
    end

    def mdr_patient_query
      TBQueries::MdrPatientQuery.new
    end

  end
end
