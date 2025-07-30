# frozen_string_literal: true

module TbService
  module Reports
    module Contacts
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

        def number_of_pulmonary_tb_cases(start_date, end_date)
          enrolled = enrolled_patients.ref(start_date, end_date)
          enrolled.with_pulmonary_tuberculosis(start_date, end_date)
        end

        def number_of_index_tb_cases(start_date, end_date)
          enrolled = enrolled_patients.ref(start_date, end_date)
          index_cases.new(enrolled).ref(start_date, end_date).cases
        end

        def number_of_hh_contacts_registered(start_date, end_date)
          enrolled = enrolled_patients.ref(start_date, end_date)
          indexes = index_cases.new(enrolled).ref(start_date, end_date).cases
          ind = index_case_contacts.ref(indexes, start_date, end_date)
          Patient.where(patient_id: ind.map(&:person_b))
        end

        def number_of_hh_contacts_screened_for_tb(start_date, end_date)
          indexes = index_cases.new.ref(start_date, end_date).cases
          ind = index_case_contacts.ref(indexes, start_date, end_date)
          screened = screened_patients.ref(start_date, end_date)

          screened.merge(Patient.where(patient_id: ind.map(&:person_b)))
        end

        def number_of_hh_contacts_with_presumptive_tb(start_date, end_date)
          indexes = index_cases.new.ref(start_date, end_date).cases
          ind = index_case_contacts.ref(indexes, start_date, end_date)
          presumptives = presumptive_patients.ref(start_date, end_date).cases

          presumptives.merge(Patient.where(patient_id: ind.map(&:person_b)))
        end

        def number_of_tb_cases_among_hh_contacts(start_date, end_date)
          indexes = index_cases.new.ref(start_date, end_date).cases
          ind = index_case_contacts.ref(indexes, start_date, end_date)

          Patient.where(patient_id: ind.with_tb(start_date, end_date).map(&:person_b))
        end

        def number_of_under_fives_among_hh_contacts(start_date, end_date)
          indexes = index_cases.new.ref(start_date, end_date).cases
          ind = index_case_contacts.ref(indexes, start_date, end_date)
          Patient.joins(:person)\
                 .where(patient_id: ind.map(&:person_b))\
                 .where('TIMESTAMPDIFF(YEAR, person.birthdate, NOW()) <= 5')
        end

        def number_of_under_fives_with_tb_among_hh_contacts(start_date, end_date)
          indexes = index_cases.new.ref(start_date, end_date).cases
          ind = index_case_contacts.ref(indexes, start_date, end_date)

          Patient.where(patient_id: ind.with_tb(start_date, end_date).under_five.map(&:person_b))
        end

        def number_of_eligible_under_fives_on_ipt(start_date, end_date)
          query = ipt_candidates_query.ref(start_date, end_date)
          query.under_fives(start_date, end_date)\
               .on_ipt(start_date, end_date)
        end

        private

        def index_cases
          TbService::TbQueries::IndexCasesQuery
        end

        def enrolled_patients
          TbService::TbQueries::EnrolledPatientsQuery.new
        end

        def index_case_contacts
          TbService::TbQueries::IndexCaseContactsQuery.new
        end

        def screened_patients
          TbService::TbQueries::ScreenedPatientsQuery.new
        end

        def presumptive_patients
          TbService::TbQueries::PresumptivePatientsQuery.new
        end

        def ipt_candidates_query
          TbService::TbQueries::IptCandidatesQuery.new
        end
      end
    end
  end
end
