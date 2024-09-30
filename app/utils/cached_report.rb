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
    @start_date = start_date.to_date.strftime("%Y-%m-%d 00:00:00")
    @end_date = end_date.to_date.strftime("%Y-%m-%d 23:59:59")
    @org = kwargs[:definition]
    @rebuild = kwargs[:rebuild]&.casecmp?("true")
    @occupation = kwargs[:occupation]
    @report_type = @org&.downcase&.match(/pepfar/i) ? "pepfar" : "moh"
    find_or_initialize_cohort
  end

  def initialize_cohort
    ArtService::Reports::CohortBuilder.new.init_temporary_tables(@start_date, @end_date, @occupation)
  end

  def find_or_initialize_cohort
    initialize_cohort if @rebuild

    initialize_cohort unless report_saved? && all_temp_tables_are_ok
  end

  def all_temp_tables_are_ok
    # check if table exists and has the corrent column count
    TEMP_TABLES_COLUMN_COUNT.all? do |table_name, column_count|
      check_if_table_exists(table_name) && count_table_columns(table_name) == column_count
    end
  end

  def report_saved?
    Report.exists?(
      type: ReportType.find_by_name("Cohort"),
      start_date: @start_date,
      end_date: @end_date,
    )
  end
end
