# frozen_string_literal: true

require 'ostruct'

module ARTService
  class ReportEngine
    attr_reader :program

    LOGGER = Rails.logger

    REPORTS = {
      'APPOINTMENTS' => ARTService::Reports::AppointmentsReport,
      'ARV_REFILL_PERIODS' => ARTService::Reports::ArvRefillPeriods,
      'COHORT' => ARTService::Reports::Cohort,
      'COHORT_DISAGGREGATED' => ARTService::Reports::CohortDisaggregated,
      'COHORT_DISAGGREGATED_ADDITIONS' => ARTService::Reports::CohortDisaggregatedAdditions,
      'COHORT_SURVIVAL_ANALYSIS' => ARTService::Reports::CohortSurvivalAnalysis,
      'DRUG_DISPENSATIONS' => ARTService::Reports::DrugDispensations,
      'IPT' => ARTService::Reports::IPTReport,
      'PATIENTS_WITH_OUTDATED_DEMOGRAPHICS' => ARTService::Reports::PatientsWithOutdatedDemographics,
      'PATIENTS_ON_DTG' => ARTService::Reports::PatientsOnDTG,
      'PREGNANT_PATIENTS' => ARTService::Reports::PregnantPatients,
      'REGIMENS_AND_FORMULATIONS' => ARTService::Reports::RegimensAndFormulations,
      'REGIMENS_BY_WEIGHT_AND_GENDER' => ARTService::Reports::RegimensByWeightAndGender,
      'REGIMEN_SWITCH' => ARTService::Reports::RegimenSwitch,
      'RETENTION' => ARTService::Reports::Retention,
      'TB_PREV2' => ARTService::Reports::Pepfar::TbPrev2,
      'TPT_NEWLY_INITIATED' => ARTService::Reports::TptNewlyInitiated,
      'TX_CURR' => ARTService::Reports::PatientsAliveAndOnTreatment,
      'TX_ML' => ARTService::Reports::Pepfar::TxMl,
      'TX_RTT' => ARTService::Reports::Pepfar::TxRTT,
      'IPT_COVERAGE' => ARTService::Reports::IPTCoverage,
      'VISITS' => ARTService::Reports::VisitsReport,
      'VL_DUE' => ARTService::Reports::PatientsDueForViralLoad,
      'VL_DISAGGREGATED' => ARTService::Reports::ViralLoadDisaggregated,
      'TB_PREV' => ARTService::Reports::Pepfar::TbPrev,
      'OUTCOME_LIST' => ARTService::Reports::OutcomeList,
      'VIRAL_LOAD' => ARTService::Reports::ViralLoad
    }.freeze

    def generate_report(type:, **kwargs)
      call_report_manager(:build_report, type: type, **kwargs)
    end

    def find_report(type:, **kwargs)
      call_report_manager(:find_report, type: type, **kwargs)
    end

    def cohort_disaggregated(quarter, age_group, start_date, end_date, rebuild, init)
      cohort = REPORTS['COHORT_DISAGGREGATED'].new(type: 'disaggregated',
        name: 'disaggregated', start_date: start_date,
        end_date: end_date, rebuild: rebuild)

      return cohort.initialize_disaggregated if init
      cohort.disaggregated(quarter, age_group)
    end

    def cohort_survival_analysis(quarter, age_group, regenerate)
      cohort = REPORTS['COHORT_SURVIVAL_ANALYSIS'].new(type: 'survival_analysis',
        name: 'survival_analysis', start_date: Date.today,
        end_date: Date.today, regenerate: regenerate)
      cohort.survival_analysis(quarter, age_group)
    end

    def defaulter_list(start_date, end_date, pepfar)
      REPORTS['COHORT'].new(type: 'defaulter_list',
        name: 'defaulter_list', start_date: start_date,
        end_date: end_date).defaulter_list(pepfar)
    end

    def missed_appointments(start_date, end_date)
      REPORTS['APPOINTMENTS'].new(start_date: start_date.to_date,
        end_date: end_date.to_date).missed_appointments
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

    def regimen_switch(start_date, end_date, pepfar)
      REPORTS['REGIMEN_SWITCH'].new(start_date: start_date.to_date,
        end_date: end_date.to_date).regimen_switch(pepfar)
    end

    def regimen_report(start_date, end_date, type)
      REPORTS['REGIMEN_SWITCH'].new(start_date: start_date.to_date,
        end_date: end_date.to_date).regimen_report(type)
    end

    def screened_for_tb(start_date, end_date, gender, age_group, outcome_table)
      REPORTS['COHORT_DISAGGREGATED_ADDITIONS'].new(start_date: start_date.to_date,
        end_date: end_date.to_date, age_group: age_group, gender: gender, outcome_table: outcome_table).screened_for_tb
    end

    def clients_given_ipt(start_date, end_date, gender, age_group, outcome_table)
      REPORTS['COHORT_DISAGGREGATED_ADDITIONS'].new(start_date: start_date.to_date,
        end_date: end_date.to_date, age_group: age_group, gender: gender, outcome_table: outcome_table).clients_given_ipt
    end

    def arv_refill_periods(start_date, end_date, min_age, max_age, org)
      REPORTS['ARV_REFILL_PERIODS'].new(start_date: start_date.to_date,
        end_date: end_date.to_date, min_age: min_age, max_age: max_age, org: org).arv_refill_periods
    end

    def tx_ml(start_date, end_date)
      REPORTS['TX_ML'].new(start_date: start_date.to_date, end_date: end_date.to_date).data
    end

    def tx_rtt(start_date, end_date)
      REPORTS['TX_RTT'].new(start_date: start_date.to_date, end_date: end_date.to_date).data
    end

    def ipt_coverage(start_date, end_date)
      REPORTS['IPT_COVERAGE'].new(start_date: start_date.to_date, end_date: end_date.to_date).data
    end

    def disaggregated_regimen_distribution(start_date, end_date, gender, age_group, outcome_table)
      REPORTS['COHORT_DISAGGREGATED_ADDITIONS'].new(start_date: start_date.to_date,
        end_date: end_date.to_date, age_group: age_group, gender: gender,
          outcome_table: outcome_table).disaggregated_regimen_distribution
    end

    def tx_mmd_client_level_data(start_date, end_date, patient_ids, org)
      REPORTS['ARV_REFILL_PERIODS'].new(start_date: start_date.to_date,
        end_date: end_date.to_date, min_age: 0, max_age: 0,
          org: org).tx_mmd_client_level_data(patient_ids)
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

    def patient_outcome_list(start_date, end_date, outcome)
      REPORTS['OUTCOME_LIST'].new(start_date: start_date.to_date,
        end_date: end_date.to_date, outcome: outcome).get_list
    end

    def clients_due_vl(start_date, end_date)
      REPORTS['VIRAL_LOAD'].new(start_date: start_date.to_date,
        end_date: end_date.to_date).clients_due
    end

    def vl_results(start_date, end_date)
      REPORTS['VIRAL_LOAD'].new(start_date: start_date.to_date,
        end_date: end_date.to_date).vl_results
    end

    private

    def call_report_manager(method, type:, **kwargs)
      start_date = kwargs.delete(:start_date)
      end_date = kwargs.delete(:end_date)
      name = kwargs.delete(:name)
      type = report_type(type)

      report_manager = REPORTS[type.name.upcase].new(
        type: type, name: name, start_date: start_date, end_date: end_date, **kwargs
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
