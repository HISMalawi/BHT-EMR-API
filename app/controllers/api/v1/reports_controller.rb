class Api::V1::ReportsController < ApplicationController
  def index
    date = params.require %i[date]
    stats = service.dashboard_stats(date.first)

    if stats
      render json: stats
    else
      render status: :no_content
    end
  end

  def with_nids
    stats = service.with_nids
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

    init = (init == 'true' ? true : false)
    start_date = Date.today
    end_date = Date.today
    rebuild_outcome = (rebuild == 'true' ? true : false)

    if(quarter == 'pepfar')
      start_date, end_date = params.require %i[start_date end_date]
      start_date = start_date.to_date
      end_date = end_date.to_date
    end

    stats = service.cohort_disaggregated(quarter, age_group, start_date,
      end_date, rebuild_outcome, init)
    render json: stats
  end

  def drugs_given_without_prescription
    start_date, end_date = params.require %i[start_date end_date]
    stats = service.drugs_given_without_prescription(start_date, end_date)

    render json: stats
  end

  def drugs_given_with_prescription
    start_date, end_date = params.require %i[start_date end_date]
    stats = service.drugs_given_with_prescription(start_date, end_date)

    render json: stats
  end

  def cohort_survival_analysis
    quarter, age_group, reg = params.require %i[quarter age_group regenerate]
    reg = (reg == 'true' ? true : false)
    stats = service.cohort_survival_analysis(quarter, age_group, reg)

    render json: stats
  end

  def anc_cohort_disaggregated
    curr_date, start_date = params.require %i[date start_date]
    stats = service.anc_cohort_disaggregated(curr_date, start_date)

    render json: stats
  end
  
  def defaulter_list
    start_date, end_date, pepfar = params.require %i[start_date end_date pepfar]
    pepfar = (pepfar == 'true' ? true : false)
    stats = service.defaulter_list(start_date, end_date, pepfar)

    render json: stats
  end

  def missed_appointments
    start_date, end_date = params.require %i[start_date end_date]
    stats = service.missed_appointments(start_date, end_date)

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
    pepfar = params[:pepfar] == 'true' ? true : false
    render json: service.regimen_switch(params[:start_date], params[:end_date], pepfar)
  end

  def regimen_report
    render json: service.regimen_report(params[:start_date], params[:end_date])
  end

  def screened_for_tb
    render json: service.screened_for_tb(params[:start_date], params[:end_date], 
      params[:gender], params[:age_group], params[:outcome_table])
  end

  def clients_given_ipt
    render json: service.clients_given_ipt(params[:start_date], params[:end_date], 
      params[:gender], params[:age_group], params[:outcome_table])
  end

  def arv_refill_periods
    render json: service.arv_refill_periods(params[:start_date], params[:end_date], 
      params[:min_age], params[:max_age])
  end

  private

  def service
    return @service if @service

    program_id, date = params.require %i[program_id date]

    @service = ReportService.new program_id: program_id
    @service
  end
end
