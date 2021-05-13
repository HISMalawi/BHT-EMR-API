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

    start_date =  params[:start_date].to_date if params.include?(:start_date)
    end_date = params[:end_date].to_date if params.include?(:end_date)

    start_date = Date.today if start_date.blank?
    end_date = Date.today if end_date.blank?
    rebuild_outcome = (rebuild == 'true' ? true : false)

    if(quarter == 'pepfar')
      start_date, end_date = params.require %i[start_date end_date]
      start_date = start_date.to_date
      end_date = end_date.to_date
    elsif quarter.match('Q')
      year = quarter.split(' ')[1].to_i
      index = quarter.split(' ')[0]
      start_date, end_date = quarter_to_date(index, year)
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
    render json: service.regimen_report(params[:start_date], params[:end_date], params[:type])
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
      params[:min_age], params[:max_age], params[:org])
  end

  def tx_ml
    render json: service.tx_ml(params[:start_date], params[:end_date])
  end

  def tx_rtt
    render json: service.tx_rtt(params[:start_date], params[:end_date])
  end

  def ipt_coverage
    render json: service.ipt_coverage(params[:start_date], params[:end_date])
  end

  def disaggregated_regimen_distribution
    render json: service.disaggregated_regimen_distribution(params[:start_date], params[:end_date],
      params[:gender], params[:age_group], params[:outcome_table])
  end

  def tx_mmd_client_level_data
    render json: service.tx_mmd_client_level_data(params[:start_date],
       params[:end_date], params[:patient_ids],  params[:org])
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
      params[:end_date], params[:outcome])
  end

  def clients_due_vl
    render json: service.clients_due_vl(params[:start_date], params[:end_date])
  end

  def vl_results
    render json: service.vl_results(params[:start_date], params[:end_date])
  end

  private

  def service
    return @service if @service

    program_id, date = params.require %i[program_id date]

    @service = ReportService.new program_id: program_id
    @service
  end

  def quarter_to_date(index, year)
    index = index.upcase
    year = year.to_i

    if index == 'Q1'
      return ["#{year}-01-01".to_date, "#{year}-03-31".to_date]
    elsif index == 'Q2'
      return ["#{year}-04-01".to_date, "#{year}-06-30".to_date]
    elsif index == 'Q3'
      return ["#{year}-07-01".to_date, "#{year}-09-30".to_date]
    elsif index == 'Q4'
      return ["#{year}-10-01".to_date, "#{year}-12-31".to_date]
    end
  end

end
