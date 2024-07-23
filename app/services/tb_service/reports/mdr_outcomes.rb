# frozen_string_literal: true

module TbService::Reports::MdrOutcomes
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

    def format_report(indicator:, report_data:, **kwargs)
      data = report_format(indicator)
      report_data&.each do |patient|
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
      TbService::TbQueries::MdrOutcomeQuery.new
    end

    def mdr_patient_query
      TbService::TbQueries::MdrPatientQuery.new
    end

  end
end
