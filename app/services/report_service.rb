# frozen_string_literal: true

class ReportService
  ENGINES = {
    'HIV PROGRAM' => ARTService::ReportEngine,
    'ANC PROGRAM' => ANCService::ReportEngine,
    'OPD PROGRAM' => OPDService::ReportEngine,
    'VMMC PROGRAM' => VMMCService::ReportEngine,
    'TB PROGRAM' => TBService::ReportEngine
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

    lock = self.class.acquire_report_lock(type, start_date, end_date)
    return nil unless lock

    LOGGER.debug("#{name} report not found... Queueing one...")
    queue_report(name: name, type: type, start_date: start_date,
                 end_date: end_date, lock: lock, **kwargs)
    nil
  end

  def self.acquire_report_lock(report_type_name, start_date, end_date)
    path = lock_file_path(report_type_name, start_date, end_date)

    if path.exist? && (File.stat(path).mtime + 12.hours) > Time.now
      LOGGER.debug("Report is locked: #{path}")
      return nil
    end

    File.open(path, 'w') do |fout|
      fout << "Locked by #{User.current.username} @ #{Time.now}"
    end

    LOGGER.debug("Report lock file created: #{path}")
    path
  end

  def self.release_report_lock(path)
    path = Pathname.new(path)
    return unless path.exist?

    File.unlink(path)
  end

  def dashboard_stats(date)
    engine(@program).dashboard_stats(date)
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

  def with_nids
    engine(@program).with_nids
  end

  def cohort_disaggregated(quarter, age_group, start_date, end_date, rebuild, init)
    engine(@program).cohort_disaggregated(quarter, age_group,
      start_date, end_date, rebuild, init)
  end

  def drugs_given_without_prescription(start_date, end_date)
    engine(@program).drugs_given_without_prescription(start_date, end_date)
  end

  def drugs_given_with_prescription(start_date, end_date)
    engine(@program).drugs_given_with_prescription(start_date, end_date)
  end

  def cohort_survival_analysis(quarter, age_group, regenerate)
    engine(@program).cohort_survival_analysis(quarter, age_group, regenerate)
  end

  def defaulter_list(start_date, end_date, pepfar)
    engine(@program).defaulter_list(start_date, end_date, pepfar)
  end

  def missed_appointments(start_date, end_date)
    engine(@program).missed_appointments(start_date, end_date)
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

  def regimen_switch(start_date, end_date, pepfar)
    engine(@program).regimen_switch(start_date, end_date, pepfar)
  end

  def regimen_report(start_date, end_date, type)
    engine(@program).regimen_report(start_date, end_date, type)
  end

  def screened_for_tb(start_date, end_date, gender, age_group, outcome_table)
    engine(@program).screened_for_tb(start_date, end_date, gender, age_group, outcome_table)
  end

  def clients_given_ipt(start_date, end_date, gender, age_group, outcome_table)
    engine(@program).clients_given_ipt(start_date, end_date, gender, age_group, outcome_table)
  end

  def arv_refill_periods(start_date, end_date, min_age, max_age, org)
    engine(@program).arv_refill_periods(start_date, end_date, min_age, max_age, org)
  end

  def tx_ml(start_date, end_date)
    engine(@program).tx_ml(start_date, end_date)
  end

  def tx_rtt(start_date, end_date)
    engine(@program).tx_rtt(start_date, end_date)
  end

  def ipt_coverage(start_date, end_date)
    engine(@program).ipt_coverage(start_date, end_date)
  end

  def disaggregated_regimen_distribution(start_date, end_date, gender, age_group, outcome_table)
    engine(@program).disaggregated_regimen_distribution(start_date, end_date, gender, age_group, outcome_table)
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

  def patient_outcome_list(start_date, end_date, outcome)
    engine(@program).patient_outcome_list(start_date, end_date, outcome)
  end

  def clients_due_vl(start_date, end_date)
    engine(@program).clients_due_vl(start_date, end_date)
  end

  def vl_results(start_date, end_date)
    engine(@program).vl_results(start_date, end_date)
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
    engine(@program).find_report(type: type, name: name,
                                 start_date: start_date, end_date: end_date,
                                 **kwargs)
  end

  def queue_report(start_date:, end_date:, lock:, **kwargs)
    kwargs[:start_date] = start_date.to_s
    kwargs[:end_date] = end_date.to_s
    kwargs[:user] = User.current.user_id
    kwargs[:lock] = lock.to_s

    LOGGER.debug("Queueing #{kwargs['type']} report: #{kwargs}")
    if @immediate_mode
      ReportJob.perform_now(engine(@program).class.to_s, **kwargs)
    else
      ReportJob.perform_later(engine(@program).class.to_s, **kwargs)
    end
  end

  def self.lock_file_path(report_type_name, start_date, end_date)
    Rails.root.join('tmp', "#{report_type_name}-report-#{start_date}-to-#{end_date}.lock")
  end
end
