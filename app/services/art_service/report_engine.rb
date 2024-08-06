# frozen_string_literal: true

require 'ostruct'

module ArtService
  class ReportEngine
    attr_reader :program

    LOGGER = Rails.logger

    REPORTS = {
      'ARCHIVING_CANDIDATES' => ArtService::Reports::ArchivingCandidates,
      'APPOINTMENTS' => ArtService::Reports::AppointmentsReport,
      'ARV_REFILL_PERIODS' => ArtService::Reports::ArvRefillPeriods,
      'VL_SUPRESSION' => ArtService::Reports::Clinic::VlSupressionReport,
      'COHORT' => ArtService::Reports::ArtCohort,
      'COHORT_DISAGGREGATED' => ArtService::Reports::Cohort::Disaggregated,
      'COHORT_DISAGGREGATED_ADDITIONS' => ArtService::Reports::CohortDisaggregatedAdditions,
      'COHORT_SURVIVAL_ANALYSIS' => ArtService::Reports::CohortSurvivalAnalysis,
      'DRUG_DISPENSATIONS' => ArtService::Reports::DrugDispensations,
      'HIGH_VL_PATIENTS' => ArtService::Reports::ViralLoadResults,
      'IPT' => ArtService::Reports::IptReport,
      'PATIENTS_WITH_OUTDATED_DEMOGRAPHICS' => ArtService::Reports::PatientsWithOutdatedDemographics,
      'PATIENTS_ON_DTG' => ArtService::Reports::PatientsOnDtg,
      'PREGNANT_PATIENTS' => ArtService::Reports::PregnantPatients,
      'REGIMENS_AND_FORMULATIONS' => ArtService::Reports::RegimensAndFormulations,
      'REGIMENS_BY_WEIGHT_AND_GENDER' => ArtService::Reports::RegimensByWeightAndGender,
      'REGIMEN_SWITCH' => ArtService::Reports::RegimenSwitch,
      'RETENTION' => ArtService::Reports::Retention,
      'LIMS_ELECTRONIC_RESULTS' => ArtService::Reports::LimsResults,
      'TPT_OUTCOME' => ArtService::Reports::TptOutcome,
      'CLINIC_TX_RTT' => ArtService::Reports::ClinicTxRtt,
      'TB_PREV2' => ArtService::Reports::Pepfar::TbPrev3,
      'TPT_NEWLY_INITIATED' => ArtService::Reports::TptNewlyInitiated,
      'TX_CURR' => ArtService::Reports::PatientsAliveAndOnTreatment,
      'TX_CURR_MMD' => ArtService::Reports::Pepfar::TxCurrMmd,
      'TX_ML' => ArtService::Reports::Pepfar::TxMl,
      'TX_RTT' => ArtService::Reports::Pepfar::TxRtt,
      'IPT_COVERAGE' => ArtService::Reports::IptCoverage,
      'VISITS' => ArtService::Reports::VisitsReport,
      'VL_DUE' => ArtService::Reports::PatientsDueForViralLoad,
      'VL_DISAGGREGATED' => ArtService::Reports::ViralLoadDisaggregated,
      'TB_PREV' => ArtService::Reports::Pepfar::TbPrev,
      'OUTCOME_LIST' => ArtService::Reports::OutcomeList,
      'VIRAL_LOAD' => ArtService::Reports::ViralLoad,
      'VIRAL_LOAD_COVERAGE' => ArtService::Reports::Pepfar::ViralLoadCoverage2,
      'EXTERNAL_CONSULTATION_CLIENTS' => ArtService::Reports::ExternalConsultationClients,
      'SC_ARVDISP' => ArtService::Reports::Pepfar::ScArvdisp,
      'SC_CURR' => ArtService::Reports::Pepfar::ScCurr,
      'PATIENT_ART_VL_DATES' => ArtService::Reports::Pepfar::PatientStartVl,
      'MOH_TPT' => ArtService::Reports::MohTpt,
      'TX_TB' => ArtService::Reports::Pepfar::TxTb,
      'VL_COLLECTION' => ArtService::Reports::VlCollection,
      'DISCREPANCY_REPORT' => ArtService::Reports::Clinic::DiscrepancyReport,
      'STOCK_CARD' => ArtService::Reports::Clinic::StockCardReport,
      'HYPERTENSION_REPORT' => ArtService::Reports::Clinic::HypertensionReport,
      'TX_NEW' => ArtService::Reports::Pepfar::TxNew,
      'AHD_MONTHLY' => ArtService::Reports::Ahd::Monthly,
      'AHD_MONTHLY_DISAGGREGATED' => ArtService::Reports::Ahd::MonthlyDisaggregated,
      'AHD_WEEKLY' => ArtService::Reports::Ahd::Weekly
    }.freeze

    def generate_report(type:, **kwargs)
      call_report_manager(:build_report, type:, **kwargs)
    end

    def find_report(type:, **kwargs)
      call_report_manager(:find_report, type:, **kwargs)
    end

    def cohort_disaggregated(quarter, age_group, start_date, end_date, rebuild, init, **kwargs)
      cohort = REPORTS['COHORT_DISAGGREGATED'].new(type: 'disaggregated', name: 'disaggregated', start_date:,
                                                   end_date:, rebuild:, **kwargs)
      return cohort.initialize_disaggregated if init

      cohort.disaggregated(quarter, age_group)
    end

    def cohort_survival_analysis(quarter, age_group, regenerate, occupation)
      cohort = REPORTS['COHORT_SURVIVAL_ANALYSIS'].new(type: 'survival_analysis',
                                                       name: 'survival_analysis', start_date: Date.today,
                                                       end_date: Date.today, regenerate:, occupation:)
      cohort.survival_analysis(quarter, age_group)
    end

    def defaulter_list(start_date, end_date, pepfar, **kwargs)
      REPORTS['COHORT'].new(type: 'defaulter_list',
                            name: 'defaulter_list', start_date:,
                            end_date:, **kwargs).defaulter_list(pepfar)
    end

    def missed_appointments(start_date, end_date, **kwargs)
      REPORTS['APPOINTMENTS'].new(start_date: start_date.to_date,
                                  end_date: end_date.to_date, **kwargs).missed_appointments
    end

    def ipt_coverage(start_date, end_date)
      REPORTS['IPT'].new(start_date: start_date.to_date,
                         end_date: end_date.to_date).ipt_coverage
    end

    def cohort_report_drill_down(id)
      REPORTS['COHORT'].new(type: 'drill_down',
                            name: 'drill_down', start_date: Date.today,
                            end_date: Date.today).cohort_report_drill_down(id)
    end

    def regimen_switch(start_date, end_date, pepfar, **kwargs)
      REPORTS['REGIMEN_SWITCH'].new(start_date: start_date.to_date,
                                    end_date: end_date.to_date, **kwargs)
                               .regimen_switch(pepfar)
    end

    def regimen_report(start_date, end_date, type, **kwargs)
      REPORTS['REGIMEN_SWITCH'].new(start_date: start_date.to_date,
                                    end_date: end_date.to_date, **kwargs)
                               .regimen_report(type)
    end

    def screened_for_tb(start_date, end_date, gender, age_group)
      REPORTS['COHORT_DISAGGREGATED_ADDITIONS'].new(start_date: start_date.to_date,
                                                    end_date: end_date.to_date, age_group:, gender:).screened_for_tb
    end

    def clients_given_ipt(start_date, end_date, gender, age_group)
      REPORTS['COHORT_DISAGGREGATED_ADDITIONS'].new(start_date: start_date.to_date,
                                                    end_date: end_date.to_date, age_group:, gender:).clients_given_ipt
    end

    def arv_refill_periods(start_date, end_date, min_age, max_age, org, initialize_tables, **kwargs)
      REPORTS['ARV_REFILL_PERIODS'].new(start_date: start_date.to_date,
                                        end_date: end_date.to_date, min_age:,
                                        max_age:, org:, initialize_tables:, **kwargs).arv_refill_periods
    end

    def tx_ml(start_date, end_date, **kwargs)
      REPORTS['TX_ML'].new(start_date: start_date.to_date, end_date: end_date.to_date, **kwargs).data
    end

    def tx_rtt(start_date, end_date, **kwargs)
      REPORTS['TX_RTT'].new(start_date: start_date.to_date, end_date: end_date.to_date, **kwargs).data
    end

    def moh_tpt(start_date, end_date, **kwargs)
      REPORTS['MOH_TPT'].new(start_date: start_date.to_date, end_date: end_date.to_date, **kwargs).data
    end

    def ipt_coverage(start_date, end_date)
      REPORTS['IPT_COVERAGE'].new(start_date: start_date.to_date, end_date: end_date.to_date).data
    end

    def disaggregated_regimen_distribution(start_date, end_date, gender, age_group)
      REPORTS['COHORT_DISAGGREGATED_ADDITIONS'].new(start_date: start_date.to_date,
                                                    end_date: end_date.to_date, age_group:, gender:).disaggregated_regimen_distribution
    end

    def tx_mmd_client_level_data(start_date, end_date, patient_ids, org)
      REPORTS['ARV_REFILL_PERIODS'].new(start_date: start_date.to_date,
                                        end_date: end_date.to_date, min_age: 0, max_age: 0,
                                        org:, initialize_tables: '').tx_mmd_client_level_data(patient_ids)
    end

    def tb_prev(start_date, end_date)
      REPORTS['TB_PREV'].new(start_date: start_date.to_date, end_date: end_date.to_date).report
    end

    def patient_visit_types(start_date, end_date)
      REPORTS['APPOINTMENTS'].new(start_date: start_date.to_date,
                                  end_date: end_date.to_date).patient_visit_types
    end

    def patient_visit_list(start_date, end_date)
      REPORTS['APPOINTMENTS'].new(start_date: start_date.to_date,
                                  end_date: end_date.to_date).patient_visit_list
    end

    def patient_outcome_list(start_date, end_date, outcome, **kwargs)
      REPORTS['OUTCOME_LIST'].new(start_date: start_date.to_date,
                                  end_date: end_date.to_date, outcome:, **kwargs).get_list
    end

    def clients_due_vl(start_date, end_date, **kwargs)
      REPORTS['VIRAL_LOAD'].new(start_date: start_date.to_date,
                                end_date: end_date.to_date, **kwargs)
                           .clients_due
    end

    def vl_results(start_date, end_date)
      REPORTS['VIRAL_LOAD'].new(start_date: start_date.to_date,
                                end_date: end_date.to_date).vl_results
    end

    def external_consultation_clients(start_date, end_date, **kwargs)
      REPORTS['EXTERNAL_CONSULTATION_CLIENTS'].new(start_date: start_date.to_date,
                                                   end_date: end_date.to_date, **kwargs).list
    end

    def vl_maternal_status(start_date, end_date,
                           tx_curr_definition, patient_ids)
      REPORTS['VIRAL_LOAD_COVERAGE'].new(start_date: start_date.to_date,
                                         end_date: end_date.to_date,
                                         tx_curr_definition:).vl_maternal_status(patient_ids)
    end

    def patient_art_vl_dates(end_date, patient_ids)
      REPORTS['PATIENT_ART_VL_DATES'].new.get_patients_last_vl_and_latest_result(patient_ids, end_date)
    end

    def latest_regimen_dispensed(start_date, end_date, rebuild_outcome, **kwargs)
      REPORTS['REGIMEN_SWITCH'].new(start_date: start_date.to_date,
                                    end_date: end_date.to_date, **kwargs).latest_regimen_dispensed(rebuild_outcome)
    end

    def sc_arvdisp(start_date, end_date, rebuild_outcome)
      REPORTS['SC_ARVDISP'].new(start_date: start_date.to_date,
                                end_date: end_date.to_date, rebuild_outcome:).report
    end

    private

    def call_report_manager(method, type:, **kwargs)
      start_date = kwargs.delete(:start_date)
      end_date = kwargs.delete(:end_date)
      name = kwargs.delete(:name)
      type = report_type(type)

      report_manager = REPORTS[type.name.upcase].new(
        type:, name:, start_date:, end_date:, **kwargs
      )

      report_manager.send(method)
    end

    def report_type(name)
      type = ReportType.find_by_name(name)
      return type if type

      return OpenStruct.new(name: name.upcase) if REPORTS[name.upcase]

      raise NotFoundError, "Report, #{name}, not found"
    end
  end
end
