# frozen_string_literal: true

module AncService
  class ReportEngine
    attr_reader :program

    LOGGER = Rails.logger

    REPORTS = {
      'COHORT' => AncService::Reports::Cohort,
      'MONTHLY' => AncService::Reports::Monthly,
      'ANC_COHORT_DISAGGREGATED' => AncService::Reports::CohortDisaggregated,
      'VISITS' => AncService::Reports::VisitsReport,
      'PMTCT_STAT_ART' => AncService::Reports::Pepfar::PmtctStatArt
    }.freeze

    def generate_report(type:, **kwargs)
      call_report_manager(:build_report, type: type, **kwargs)
    end

    def find_report(type:, **kwargs)
      call_report_manager(:find_report, type: type, **kwargs)
    end

    def cohort_disaggregated(date, start_date)
      start_date = start_date.to_date.beginning_of_month
      end_date = start_date.to_date.end_of_month
      cohort = REPORTS['ANC_COHORT_DISAGGREGATED'].new(type: 'disaggregated',
                                                       name: 'disaggregated', start_date: start_date,
                                                       end_date: end_date, rebuild: false)

      cohort.disaggregated(date, start_date, end_date)
    end

    def dashboard_stats(_date = nil)
      queries = AncService::DashboardStatsQueries.new
      stats = {
        new_and_continuing_anc_clients: queries.new_and_continuing_anc_clients,
        women_with_ultrasound_scanning: queries.women_with_ultrasound_scanning,
        proportion_women_ultrasound_scanning: queries.proportion_women_ultrasound_scanning,
        women_with_4_plus_anc_contacts: queries.women_with_4_plus_anc_contacts,
        percentage_women_4_plus_anc_contacts: queries.percentage_women_4_plus_anc_contacts,
        clients_with_previous_uterine_scars: queries.clients_with_previous_uterine_scars,
        percentage_clients_previous_uterine_scars: queries.percentage_clients_previous_uterine_scars,
        anc_hiv_positive_clients: queries.anc_hiv_positive_clients,
        anc_hiv_positive_on_art: queries.anc_hiv_positive_on_art,
        percentage_anc_hiv_positive_on_art: queries.percentage_anc_hiv_positive_on_art,
        women_tested_syphilis_during_anc: queries.women_tested_syphilis_during_anc,
        percentage_women_tested_syphilis_during_anc: queries.percentage_women_tested_syphilis_during_anc,
        women_tested_hepatitis_b_during_anc: queries.women_tested_hepatitis_b_during_anc,
        percentage_women_tested_hepatitis_b_during_anc: queries.percentage_women_tested_hepatitis_b_during_anc
      }
      LOGGER.info "[ANC ReportEngine] dashboard_stats stats=#{stats}"
      stats
    end

    private

    def call_report_manager(method, type:, **kwargs)
      start_date = kwargs.delete(:start_date)
      end_date = kwargs.delete(:end_date)
      name = kwargs.delete(:name)

      report_manager = REPORTS[type.upcase].new(
        type: type, name: name, start_date: start_date, end_date: end_date
      )
      method = report_manager.method(method)
      if kwargs.empty?
        method.call
      else
        method.call(**kwargs)
      end
    end
  end
end
