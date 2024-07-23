# frozen_string_literal: true

module TbService
  module Reports
    module Tbhiv
      class << self
        def report_format(indicator)
          {
            indicator:,
            male: [],
            female: [],
            total: []
          }
        end

        def format_report(indicator:, report_data:, **kwargs)
          data = report_format(indicator)
          report_data&.each do |patient|
            process_patient(patient, data)
          end
          data
        end

        def process_patient(patient, data)
          data[:total] << patient.id unless data[:total].include?(patient.id)
          data[:male] << patient.id if patient.gender == 'M'
          data[:female] << patient.id if patient.gender == 'F'
        end

        def new_and_relapse_tb_cases_notified(start_date, end_date)
          new_cases = new_patients_query.ref(start_date, end_date)
          relapses = relapse_patients_query.ref(start_date, end_date)
          return nil if new_cases.empty? && relapses.empty?

          ids = (new_cases + relapses)
          Patient.where(patient_id: ids)
        end

        def total_with_hiv_result_documented(start_date, end_date)
          new_cases = new_patients_query.ref(start_date, end_date)
          ipt_treatment = ipt_candidates_query.ref(start_date, end_date)
          non_ipt = ipt_treatment.on_ipt(start_date, end_date)
          cases = new_cases.where.not(patient_id: non_ipt.map(&:patient_id))
          relapses = relapse_patients_query.ref(start_date, end_date)

          return if cases.empty? && relapses.empty?

          all = Patient.where(patient_id: (cases + relapses))
          query = hiv_result_query.new(all).ref
          query.documented
        end

        def total_tested_hiv_positive(start_date, end_date)
          new_cases = new_patients_query.ref(start_date, end_date)
          relapses = relapse_patients_query.ref(start_date, end_date)

          return if new_cases.empty? && relapses.empty?

          all = Patient.where(patient_id: (new_cases + relapses))
          query = hiv_result_query.new(all).ref
          query.positive
        end

        def started_cpt(start_date, end_date)
          query = new_patients_query.ref(start_date, end_date)
          relapses = relapse_patients_query.ref(start_date, end_date)
          ids = (query.on_cpt + relapses.on_cpt).map(&:patient_id)
          Patient.where(patient_id: ids)
        end

        def started_art_before_tb_treatment(start_date, end_date)
          new_cases = new_patients_query.ref(start_date, end_date)
          relapses = relapse_patients_query.ref(start_date, end_date)

          ids = (new_cases.started_before_art + relapses.started_before_art)
          Patient.where(patient_id: ids)
        end

        def started_art_while_on_treatment(start_date, end_date)
          new_cases = new_patients_query.ref(start_date, end_date)
          relapses = relapse_patients_query.ref(start_date, end_date)

          ids = (new_cases.started_while_art + relapses.started_while_art)
          Patient.where(patient_id: ids)
        end

        private

        def new_patients_query
          TbService::TbQueries::NewPatientsQuery.new
        end

        def hiv_result_query
          TbService::TbQueries::HivResultQuery
        end

        def relapse_patients_query
          TbService::TbQueries::RelapsePatientsQuery.new
        end

        def ipt_candidates_query
          TbService::TbQueries::IptCandidatesQuery.new
        end
      end
    end
  end
end
