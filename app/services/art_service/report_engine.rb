# frozen_string_literal: true

module ARTService
  class ReportEngine
    attr_reader :program

    LOGGER = Rails.logger

    REPORTS = {
      'COHORT' => ARTService::Reports::Cohort,
      'COHORT_DISAGGREGATED' => ARTService::Reports::CohortDisaggregated,
      'COHORT_SURVIVAL_ANALYSIS' => ARTService::Reports::CohortSurvivalAnalysis,
      'VISITS' => ARTService::Reports::VisitsReport,
      'APPOINTMENTS' => ARTService::Reports::AppointmentsReport,
      'IPT' => ARTService::Reports::IPTReport
    }.freeze

    def generate_report(type:, **kwargs)
      call_report_manager(:build_report, type: type, **kwargs)
    end

    def find_report(type:, **kwargs)
      call_report_manager(:find_report, type: type, **kwargs)
    end

    def cohort_report_raw_data(l1, l2)
      REPORTS['COHORT'].new(type: 'raw data', 
        name: 'raw data', start_date: Date.today,
        end_date: Date.today).raw_data(l1, l2)
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

    private

    def call_report_manager(method, type:, **kwargs)
      start_date = kwargs.delete(:start_date)
      end_date = kwargs.delete(:end_date)
      name = kwargs.delete(:name)
      type  = report_type(type)

      report_manager = REPORTS[type.name.upcase].new(
        type: type, name: name, start_date: start_date, end_date: end_date
      )
      method = report_manager.method(method)
      if kwargs.empty?
        method.call
      else
        method.call(**kwargs)
      end
    end

    def report_type(name)
      type  = ReportType.find_by_name(name)
      raise NotFoundError, "Report, #{name}, not found" unless type

      type
    end


  end
end
