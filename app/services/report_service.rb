# frozen_string_literal: true

class ReportService
  ENGINES = {
    'HIV PROGRAM' => ArtService::ReportEngine,
    'ANC PROGRAM' => AncService::ReportEngine,
    'OPD PROGRAM' => OpdService::ReportEngine,
    'VMMC PROGRAM' => VmmcService::ReportEngine,
    'TB PROGRAM' => TbService::ReportEngine,
    'LABORATORY ORDERS' => LaboratoryService::ReportEngine,
    'CXCA PROGRAM' => CxcaService::ReportEngine,
    'RADIOLOGY PROGRAM' => RadiologyService::ReportEngine,
    'PATIENT REGISTRATION PROGRAM' => PatientRegistrationService::ReportEngine,
    'HTC PROGRAM' => HtsService::ReportEngine,
    'AETC PROGRAM' => AetcService::ReportEngine,
    'SPINE PROGRAM' => SpineService::ReportEngine
  }.freeze
  LOGGER = Rails.logger

  def initialize(program_id:, immediate_mode: false, overwrite_mode: false)
    @program = Program.find(program_id)
    @immediate_mode = immediate_mode
    @overwrite_mode = overwrite_mode
  end

  def generate_report(name:, type:, start_date: Date.strptime('1900-01-01'),
                      end_date: Date.today, **kwargs)
    LOGGER.debug "Retrieving report, #{name}, for period #{start_date} to #{end_date}"
    report = find_report(type, name, start_date, end_date, **kwargs)

    if report && @overwrite_mode
      report.destroy
      report = nil
    end

    return report if report

    LOGGER.debug("#{name} report not found... Queueing one...")
    queue_report(name:, type:, start_date:, end_date:, **kwargs)
    nil
  end

  def dashboard_stats(date)
    engine(@program).dashboard_stats(date)
  end

  def dashboard_stats_for_syndromic_statistics(date)
    engine(@program).dashboard_stats_for_syndromic_statistics(date)
  end

  def diagnosis(start_date, end_date)
    engine(@program).diagnosis(start_date, end_date)
  end

  def registration(start_date, end_date)
    engine(@program).registration(start_date, end_date)
  end

  def diagnosis_by_address(start_date, end_date)
    engine(@program).diagnosis_by_address(start_date, end_date)
  end

  def with_nids(start_date, end_date)
    engine(@program).with_nids(start_date, end_date)
  end

  def cohort_disaggregated(quarter, age_group, start_date, end_date, rebuild, init, **kwargs)
    engine(@program).cohort_disaggregated(quarter, age_group, start_date, end_date, rebuild, init, **kwargs)
  end

  def dispensation(start_date, end_date)
    engine(@program).dispensation(start_date, end_date)
  end

  def cohort_survival_analysis(quarter, age_group, regenerate, occupation)
    engine(@program).cohort_survival_analysis(quarter, age_group, regenerate, occupation)
  end

  def defaulter_list(start_date, end_date, pepfar, **kwargs)
    engine(@program).defaulter_list(start_date, end_date, pepfar, **kwargs)
  end

  def missed_appointments(start_date, end_date, **kwargs)
    engine(@program).missed_appointments(start_date, end_date, **kwargs)
  end

  def anc_cohort_disaggregated(date, start_date)
    engine(@program).cohort_disaggregated(date, start_date)
  end

  def ipt_coverage(start_date, end_date)
    engine(@program).ipt_coverage(start_date, end_date)
  end

  def cohort_report_drill_down(id)
    engine(@program).cohort_report_drill_down(id)
  end

  def regimen_switch(start_date, end_date, pepfar, **kwargs)
    engine(@program).regimen_switch(start_date, end_date, pepfar, **kwargs)
  end

  def regimen_report(start_date, end_date, type, **kwargs)
    engine(@program).regimen_report(start_date, end_date, type, **kwargs)
  end

  def screened_for_tb(start_date, end_date, gender, age_group)
    engine(@program).screened_for_tb(start_date, end_date, gender, age_group)
  end

  def clients_given_ipt(start_date, end_date, gender, age_group)
    engine(@program).clients_given_ipt(start_date, end_date, gender, age_group)
  end

  def arv_refill_periods(start_date, end_date, min_age, max_age, org, initialize_tables, **kwargs)
    engine(@program).arv_refill_periods(start_date,
                                        end_date, min_age, max_age, org, initialize_tables, **kwargs)
  end

  def tx_ml(start_date, end_date, **kwargs)
    engine(@program).tx_ml(start_date, end_date, **kwargs)
  end

  def tx_rtt(start_date, end_date, **kwargs)
    engine(@program).tx_rtt(start_date, end_date, **kwargs)
  end

  def moh_tpt(start_date, end_date, **kwargs)
    engine(@program).moh_tpt(start_date, end_date, **kwargs)
  end

  def ipt_coverage(start_date, end_date)
    engine(@program).ipt_coverage(start_date, end_date)
  end

  def disaggregated_regimen_distribution(start_date, end_date, gender, age_group)
    engine(@program).disaggregated_regimen_distribution(start_date, end_date, gender, age_group)
  end

  def tx_mmd_client_level_data(start_date, end_date, patient_ids, org)
    engine(@program).tx_mmd_client_level_data(start_date, end_date, patient_ids, org)
  end

  def tb_prev(start_date, end_date)
    engine(@program).tb_prev(start_date, end_date)
  end

  def patient_visit_types(start_date, end_date)
    engine(@program).patient_visit_types(start_date, end_date)
  end

  def patient_visit_list(start_date, end_date)
    engine(@program).patient_visit_list(start_date, end_date)
  end

  def patient_outcome_list(start_date, end_date, outcome, **kwargs)
    engine(@program).patient_outcome_list(start_date, end_date, outcome, **kwargs)
  end

  def clients_due_vl(start_date, end_date, **kwargs)
    engine(@program).clients_due_vl(start_date, end_date, **kwargs)
  end

  def vl_results(start_date, end_date)
    engine(@program).vl_results(start_date, end_date)
  end

  def samples_drawn(start_date, end_date)
    engine(@program).samples_drawn(start_date, end_date)
  end

  def lab_test_results(start_date, end_date, **kwargs)
    engine(@program).test_results(start_date, end_date, **kwargs)
  end

  def orders_made(start_date, end_date, status)
    engine(@program).orders_made(start_date, end_date, status)
  end

  def external_consultation_clients(start_date, end_date, **kwargs)
    engine(@program).external_consultation_clients(start_date, end_date, **kwargs)
  end

  def cxca_reports(start_date, end_date, report_name, **kwargs)
    engine(@program).reports(start_date.to_date, end_date.to_date, report_name, **kwargs)
  end

  def radiology_reports(start_date, end_date, report_name)
    engine(@program).reports(start_date.to_date, end_date.to_date, report_name)
  end

  def pr_reports(start_date, end_date, report_name)
    engine(@program).reports(start_date.to_date, end_date.to_date, report_name)
  end

  def vl_maternal_status(start_date, end_date, tx_curr_definition, patient_ids)
    engine(@program).vl_maternal_status(start_date.to_date, end_date.to_date,
                                        tx_curr_definition, patient_ids)
  end

  def patient_art_vl_dates(end_date, patient_ids)
    engine(@program).patient_art_vl_dates(end_date.to_date, patient_ids)
  end

  def latest_regimen_dispensed(start_date, end_date, rebuild_outcome, **kwargs)
    engine(@program).latest_regimen_dispensed(start_date.to_date, end_date.to_date, rebuild_outcome, **kwargs)
  end

  def sc_arvdisp(start_date, end_date, rebuild_outcome)
    engine(@program).sc_arvdisp(start_date, end_date, rebuild_outcome)
  end

  private

  def engine(program)
    ENGINES[program_name(program)].new
  end

  def program_name(program)
    program.concept.concept_names.each do |concept_name|
      name = concept_name.name.upcase
      return name if ENGINES.include?(name)
    end
  end

  def find_report(type, name, start_date, end_date, **kwargs)
    engine(@program).find_report(type:, name:,
                                 start_date:, end_date:,
                                 **kwargs)
  end

  def queue_report(start_date:, end_date:, **kwargs)
    kwargs[:start_date] = start_date.to_s
    kwargs[:end_date] = end_date.to_s
    kwargs[:user] = User.current.user_id

    LOGGER.debug("Queueing #{kwargs['type']} report: #{kwargs}")
    if @immediate_mode
      ReportJob.perform_now(engine(@program).class.to_s, **kwargs)
    else
      ReportJob.perform_later(engine(@program).class.to_s, **kwargs)
    end
  end
end
