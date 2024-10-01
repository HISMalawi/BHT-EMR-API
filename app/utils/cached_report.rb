class CachedReport
  include ArtTempTablesUtils

  TEMP_TABLES_COLUMN_COUNT = {
    temp_cohort_members: 12,
    temp_earliest_start_date: 11,
    temp_other_patient_types: 1,
    temp_register_start_date: 2,
    temp_order_details: 2,
    temp_art_start_date: 2,
    temp_patient_tb_status: 2,
    temp_latest_tb_status: 2,
    tmp_max_adherence: 2,
    temp_pregnant_obs: 3,
    temp_patient_side_effects: 2,
  }

  def initialize(start_date:, end_date:, **kwargs)
    @start_date = start_date.to_date
    @end_date = end_date.to_date
    @org = kwargs[:definition]
    @rebuild = kwargs[:rebuild]&.casecmp?("true")
    @occupation = kwargs[:occupation]
    @report_type = @org&.downcase&.match(/pepfar/i) ? "pepfar" : "moh"
    find_or_initialize_cohort
  end

  def initialize_and_save_report
    ArtService::Reports::CohortBuilder
      .new(outcomes_definition: @report_type)
      .init_temporary_tables(@start_date, @end_date, @occupation)

    save_report
  end

  def save_report
    truncate_similar_reports

    Report.create(name: report_name,
                  start_date: @start_date,
                  end_date: @end_date,
                  type: ReportType.find_by_name("Cohort"),
                  creator: User.current.id,
                  renderer_type: "PDF")
  end

  def truncate_similar_reports
    Report.where(
      type: ReportType.find_by_name("Cohort"),
      name: report_name,
      start_date: @start_date,
      end_date: @end_date,
    ).destroy_all
  end

  def find_or_initialize_cohort
    initialize_and_save_report if @rebuild

    initialize_and_save_report unless report_saved? && all_temp_tables_are_ok?
  end

  def all_temp_tables_are_ok?
    # check if table exists and has the corrent column count
    TEMP_TABLES_COLUMN_COUNT.all? do |table_name, column_count|
      check_if_table_exists(table_name) && count_table_columns(table_name) == column_count
    end
  end

  def report_saved?
    last_saved_report = Report.where(
      type: ReportType.find_by_name("Cohort"),
      name: report_name,
    ).last

    return false unless last_saved_report.present?

    last_saved_report.start_date.to_date == @start_date.to_date && last_saved_report.end_date.to_date == @end_date.to_date
  end

  private

  def report_name
    "Cohort~#{@start_date}~#{@end_date}"
  end
end
