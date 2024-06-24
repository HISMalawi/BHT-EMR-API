# frozen_string_literal: true

include ModelUtils

module TbService
  module Reports
    module Quarterly
      class << self
        def report_format(indicator:)
          {
            indicator:,
            total: []
          }
        end

        def format_report(indicator:, report_data:)
          data = report_format(indicator:)
          report_data&.each do |patient|
            process_patient(patient, data)
          end
          data
        end

        def process_patient(patient, data)
          data[:total] << patient.id unless data[:total].include?(patient.id)
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

          return if new_cases.empty? && relapses.empty?

          all = Patient.where(patient_id: (new_cases + relapses))
          query = hiv_result_query.new(all).ref
          query.positive
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
          TbService::TbQueries::CasesQuery.new
        end

        def relapses_query
          TbService::TbQueries::RelapsePatientsQuery.new
        end

        def new_patients_query
          TbService::TbQueries::NewPatientsQuery.new
        end

        def hiv_result_query
          TbService::TbQueries::HivResultQuery
        end

        def retreatment_patients_query
          TbService::TbQueries::RetreatmentPatientsQuery.new
        end

        def ipt_candidate_query
          TbService::TbQueries::IptCandidatesQuery.new
        end
      end
    end
  end
end
