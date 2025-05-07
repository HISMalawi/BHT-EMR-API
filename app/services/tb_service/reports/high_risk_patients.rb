# frozen_string_literal: true

module TbService
  module Reports
    module HighRiskPatients
      class << self
        def report_format(indicator:)
          {
            indicator:,
            total: []
          }
        end

        def format_report(indicator:, report_data:, **_kwargs)
          data = report_format(indicator:)
          report_data&.each do |patient|
            process_patient(patient, data)
          end
          data
        end

        def process_patient(patient, data)
          data[:total] << patient.id unless data[:total].include?(patient.id)
        end

        def number_of_tb_cases_among_current_miners(start_date, end_date)
          enrolled = enrolled_patients_query.ref(start_date, end_date)
          high_risk_patients_query.new(enrolled).ref(start_date, end_date).current_miners
        end

        def number_of_tb_cases_among_ex_miners(start_date, end_date)
          enrolled = enrolled_patients_query.ref(start_date, end_date)
          high_risk_patients_query.new(enrolled).ref(start_date, end_date).ex_miners
        end

        def number_of_tb_cases_among_household_members_of_current_miners(start_date, end_date)
          enrolled = enrolled_patients_query.ref(start_date, end_date)

          miners = high_risk_patients_query.new(enrolled).ref(start_date, end_date).current_miners

          contacts = index_case_contacts_query.ref(miners, start_date, end_date)

          filtered = contacts.where(person_b: enrolled)

          Patient.where(patient_id: filtered.map(&:person_b))
        end

        def number_of_tb_cases_among_mining_communities(start_date, end_date)
          enrolled = enrolled_patients_query.ref(start_date, end_date)
          high_risk_patients_query.new(enrolled).ref(start_date, end_date).miners
        end

        def number_of_tb_cases_among_health_care_workers(start_date, end_date)
          enrolled = enrolled_patients_query.ref(start_date, end_date)
          high_risk_patients_query.new(enrolled).ref(start_date, end_date).health_care_workers
        end

        def number_of_tb_cases_among_prisoners(start_date, end_date)
          enrolled = enrolled_patients_query.ref(start_date, end_date)
          high_risk_patients_query.new(enrolled).ref(start_date, end_date).prisoners
        end

        def children_between_zero_and_fourteen(start_date, end_date)
          query = enrolled_patients_query.ref(start_date, end_date)
          query.age_range(0, 14)
        end

        def children_between_zero_and_four(start_date, end_date)
          query = enrolled_patients_query.ref(start_date, end_date)
          query.age_range(0, 4)
        end

        def children_between_five_and_fourteen(start_date, end_date)
          query = enrolled_patients_query.ref(start_date, end_date)
          query.age_range(5, 14)
        end

        def hiv_positive_tb_cases(start_date, end_date)
          query = enrolled_patients_query.ref(start_date, end_date)
          query.hiv_status_positive
        end

        private

        def enrolled_patients_query
          TbService::TbQueries::EnrolledPatientsQuery.new
        end

        def high_risk_patients_query
          TbService::TbQueries::HighRiskPatientsQuery
        end

        def index_case_contacts_query
          TbService::TbQueries::IndexCaseContactsQuery.new
        end
      end
    end
  end
end
