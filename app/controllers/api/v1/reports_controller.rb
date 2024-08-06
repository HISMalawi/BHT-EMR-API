# frozen_string_literal: true

module Api
  module V1
    class ReportsController < ApplicationController
      def index
        date = params.require %i[date]
        stats = service.dashboard_stats(date.first)

        if stats
          render json: stats
        else
          render status: :no_content
        end
      end

      def syndromic_statistics
        date = params.require %i[date]
        stats = service.dashboard_stats_for_syndromic_statistics(date.first)

        if stats
          render json: stats
        else
          render status: :no_content
        end
      end

      def with_nids
        start_date, end_date = params.require %i[start_date end_date]
        stats = service.with_nids(start_date, end_date)
        render json: stats
      end

      def malaria_report
        start_date, end_date = params.require %i[start_date end_date]
        stats = service.malaria_report(start_date, end_date)

        render json: stats
      end

      def diagnosis
        start_date, end_date = params.require %i[start_date end_date]
        stats = service.diagnosis(start_date, end_date)

        render json: stats
      end

      def registration
        start_date, end_date = params.require %i[start_date end_date]
        stats = service.registration(start_date, end_date)

        render json: stats
      end

      def diagnosis_by_address
        start_date, end_date = params.require %i[start_date end_date]
        stats = service.diagnosis_by_address(start_date, end_date)

        render json: stats
      end

      def cohort_disaggregated
        quarter, age_group,
        rebuild, init = params.require %i[quarter age_group rebuild_outcome initialize]

        init = (init == 'true')

        start_date = params[:start_date].to_date if params.include?(:start_date)
        end_date = params[:end_date].to_date if params.include?(:end_date)

        start_date = Date.today if start_date.blank?
        end_date = Date.today if end_date.blank?
        rebuild_outcome = (rebuild == 'true')

        case quarter
        when 'pepfar'
          start_date, end_date = params.require %i[start_date end_date]
          start_date = start_date.to_date
          end_date = end_date.to_date
        when 'Q'
          year = quarter.split(' ')[1].to_i
          index = quarter.split(' ')[0]
          start_date, end_date = quarter_to_date(index, year)
        end

        stats = service.cohort_disaggregated(quarter, age_group, start_date,
                                             end_date, rebuild_outcome, init,
                                             occupation: params[:occupation])
        render json: stats
      end

      def dispensation
        start_date, end_date = params.require %i[start_date end_date]
        stats = service.dispensation(start_date, end_date)

        render json: stats
      end

      def cohort_survival_analysis
        quarter, age_group, reg = params.require %i[quarter age_group regenerate]
        occupation = params[:occupation]
        reg = (reg == 'true')
        stats = service.cohort_survival_analysis(quarter, age_group, reg, occupation)

        render json: stats
      end

      def anc_cohort_disaggregated
        curr_date, start_date = params.require %i[date start_date]
        stats = service.anc_cohort_disaggregated(curr_date, start_date)

        render json: stats
      end

      def defaulter_list
        start_date, end_date, pepfar = params.require %i[start_date end_date pepfar]
        pepfar = (pepfar == 'true')
        stats = service.defaulter_list(start_date, end_date, pepfar, occupation: params[:occupation])

        render json: stats
      end

      def missed_appointments
        start_date, end_date = params.require %i[start_date end_date]
        stats = service.missed_appointments(start_date, end_date, occupation: params[:occupation])

        render json: stats
      end

      def ipt_coverage
        start_date, end_date = params.require %i[start_date end_date]
        stats = service.ipt_coverage(start_date, end_date)

        render json: stats
      end

      def cohort_report_drill_down
        render json: service.cohort_report_drill_down(params[:id])
      end

      def regimen_switch
        pepfar = params[:pepfar] == 'true'
        render json: service.regimen_switch(params[:start_date], params[:end_date], pepfar,
                                            occupation: params[:occupation])
      end

      def regimen_report
        render json: service.regimen_report(params[:start_date], params[:end_date], params[:type],
                                            occupation: params[:occupation])
      end

      def screened_for_tb
        render json: service.screened_for_tb(params[:start_date], params[:end_date],
                                             params[:gender], params[:age_group])
      end

      def clients_given_ipt
        render json: service.clients_given_ipt(params[:start_date], params[:end_date],
                                               params[:gender], params[:age_group])
      end

      def arv_refill_periods
        render json: service.arv_refill_periods(params[:start_date], params[:end_date],
                                                params[:min_age], params[:max_age], params[:org],
                                                params[:initialize_tables], occupation: params[:occupation])
      end

      def tx_ml
        render json: service.tx_ml(params[:start_date], params[:end_date], occupation: params[:occupation],
                                                                           rebuild: params[:rebuild])
      end

      def tx_rtt
        render json: service.tx_rtt(params[:start_date], params[:end_date], occupation: params[:occupation],
                                                                            rebuild: params[:rebuild])
      end

      def moh_tpt
        render json: service.moh_tpt(params[:start_date], params[:end_date], occupation: params[:occupation])
      end

      def ipt_coverage
        render json: service.ipt_coverage(params[:start_date], params[:end_date])
      end

      def disaggregated_regimen_distribution
        render json: service.disaggregated_regimen_distribution(params[:start_date],
                                                                params[:end_date], params[:gender], params[:age_group])
      end

      def tx_mmd_client_level_data
        render json: service.tx_mmd_client_level_data(params[:start_date],
                                                      params[:end_date], params[:patient_ids], params[:org])
      end

      def tb_prev
        render json: service.tb_prev(params[:start_date], params[:end_date])
      end

      def patient_visit_types
        render json: service.patient_visit_types(params[:start_date], params[:end_date])
      end

      def patient_visit_list
        render json: service.patient_visit_list(params[:date], params[:date])
      end

      def patient_outcome_list
        render json: service.patient_outcome_list(params[:start_date],
                                                  params[:end_date], params[:outcome], occupation: params[:occupation])
      end

      def clients_due_vl
        render json: service.clients_due_vl(params[:start_date], params[:end_date], occupation: params[:occupation])
      end

      def vl_results
        render json: service.vl_results(params[:start_date], params[:end_date])
      end

      def samples_drawn
        render json: service.samples_drawn(params[:start_date], params[:end_date])
      end

      def lab_test_results
        render json: service.lab_test_results(params[:start_date], params[:end_date], occupation: params[:occupation])
      end

      def orders_made
        render json: service.orders_made(params[:start_date],
                                         params[:end_date], params[:status])
      end

      def external_consultation_clients
        render json: service.external_consultation_clients(params[:start_date], params[:end_date],
                                                           occupation: params[:occupation])
      end

      def cxca_reports
        render json: service.cxca_reports(params[:start_date], params[:end_date], params[:report_name],
                                          screening_method: params[:screening_method])
      end

      def radiology_reports
        render json: service.radiology_reports(params[:start_date], params[:end_date], params[:report_name])
      end

      def pr_reports
        render json: service.pr_reports(params[:start_date], params[:end_date], params[:report_name])
      end

      def vl_maternal_status
        # vlc = ArtService::Reports::Pepfar::ViralLoadCoverage.new start_date: params[:start_date], end_date: params[:end_date]
        # result = vlc.woman_status params[:person_id].split(",").map {|number| number.to_i}
        # render json: result
        render json: service.vl_maternal_status(params[:start_date], params[:end_date],
                                                params[:report_definition], params[:patient_ids])
      end

      def patient_art_vl_dates
        render json: service.patient_art_vl_dates(params[:end_date], params[:patient_ids])
      end

      def latest_regimen_dispensed
        render json: service.latest_regimen_dispensed(params[:start_date],
                                                      params[:end_date],
                                                      params[:rebuild_outcome] == 'true',
                                                      occupation: params[:occupation])
      end

      def sc_arvdisp
        render json: service.sc_arvdisp(params[:start_date],
                                        params[:end_date], (params[:rebuild_outcome] == 'true'))
      end

      private

      def service
        return @service if @service

        program_id, = params.require %i[program_id date]

        @service = ReportService.new(program_id:)
        @service
      end

      def quarter_to_date(index, year)
        index = index.upcase
        year = year.to_i

        case index
        when 'Q1'
          ["#{year}-01-01".to_date, "#{year}-03-31".to_date]
        when 'Q2'
          ["#{year}-04-01".to_date, "#{year}-06-30".to_date]
        when 'Q3'
          ["#{year}-07-01".to_date, "#{year}-09-30".to_date]
        when 'Q4'
          ["#{year}-10-01".to_date, "#{year}-12-31".to_date]
        end
      end
    end
  end
end
