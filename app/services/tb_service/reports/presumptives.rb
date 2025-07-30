# frozen_string_literal: true

module TbService::Reports::Presumptives
  class << self

    def report_format(indicator:)
      {
        indicator: indicator,
        total: []
      }
    end

    def format_report(indicator:, report_data:, **kwargs)
      data = report_format(indicator: indicator)
      report_data&.each do |patient|
        process_patient(patient, data)
      end
      data
    end

    def process_patient(patient, data)
      data[:total] << patient.id unless data[:total].include?(patient.id)
    end

    def number_of_presumptive_tb_cases (start_date, end_date)
      query = presumptive_patients_query.ref(start_date, end_date)
      query.cases
    end

    def number_of_female_presumptive_tb_cases (start_date, end_date)
      query = presumptive_patients_query.ref(start_date, end_date)
      query.female
    end

    def number_of_male_presumptive_tb_cases (start_date, end_date)
      query = presumptive_patients_query.ref(start_date, end_date)
      query.male
    end

    def number_of_presumptive_tb_cases_on_art (start_date, end_date)
      query = presumptive_patients_query.ref(start_date, end_date)
      query.on_art
    end

    def number_of_presumptive_tb_cases_not_on_art (start_date, end_date)
      query = presumptive_patients_query.ref(start_date, end_date)
      query.not_on_art
    end

    def number_of_presumptive_tb_cases_new_positive_hiv (start_date, end_date)
      query = presumptive_patients_query.ref(start_date, end_date)
      query.hiv_positive
    end

    def number_of_hiv_negative_presumptives (start_date, end_date)
      query = presumptive_patients_query.ref(start_date, end_date)
      query.hiv_negative
    end

    def number_of_adult_opd_attendees (start_date, end_date)
      eighteen_years = 18
      query = opd_patients_query.ref(start_date, end_date)
      query.age_range(18)
    end

    def new_smear_positive (start_date, end_date)
      query = new_patients_query.ref(start_date, end_date)
      query.smear_positive(start_date, end_date)
    end

    def new_mtb_detected_xpert (start_date, end_date)
      query = new_patients_query.ref(start_date, end_date)
      query.with_mtb_through_xpert(start_date, end_date)
    end

    def new_tb_cases_among_hiv_positive_presumptives (start_date, end_date)
      query = new_patients_query.ref(start_date, end_date)
      query.with_hiv
    end

    private

    def presumptive_patients_query
      TbService::TbQueries::PresumptivePatientsQuery.new
    end

    def new_patients_query
      TbService::TbQueries::NewPatientsQuery.new
    end

    def opd_patients_query
      TbService::TbQueries::OpdPatientsQuery.new
    end
  end
end