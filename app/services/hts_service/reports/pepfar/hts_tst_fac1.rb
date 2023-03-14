module HtsService::Reports::Pepfar
  # HTS_TST_Fac1 report
  class HtsTstFac1
    include HtsService::Reports::HtsReportBuilder
    attr_reader :start_date, :end_date, :report, :numbering

    ACCESS_POINTS = { index: "Index", emergency: "Emergency", inpatient: "Inpatient",
                      malnutrition: "Malnutrition", pediatric: "Pediatric", pmtct_anc1: "ANC first visit" }

    def initialize(start_date:, end_date:)
      @start_date = start_date
      @end_date = end_date
      @report = []
      @numbering = 0
    end

    def data
      fetch_data
    end

    private

    def fetch_data
      sdata, fdata = fetch_status_data, fetch_facility_data
      data = fdata.map { |f| f.merge(sdata.find { |s| s["person_id"] == f["person_id"] }) }
      rows = hts_age_groups.collect { |age_group| construct_row age_group }.flatten
      rows = rows.collect { |row| calc_access_points data, row }
      rows.flatten.uniq
    end

    def calc_age_groups(data, age_group)
      x = data.select { |q| q["age_group"] == age_group.values.first }
      {
        pos: x.select { |q| q["status"] == HIV_POSITIVE }.map { |q| q["person_id"] },
        neg: x.select { |q| q["status"] == HIV_NEGATIVE }.map { |q| q["person_id"] },
      }
    end

    def calc_access_points(data, row)
      ACCESS_POINTS.each_with_index do |(key, value)|
        x = patients_in_access_point(data, value)
        row["#{key}"] = calc_age_groups(x.select { |q| q["gender"] == row[:gender].to_s.strip }, row[:age_group])
        row["age_group"] = row[:age_group].values.first
      end
      row
    end

    def construct_row(age_group)
      %i[M F].collect do |gender|
        {
          num_index: @numbering += 1,
          gender: gender,
          age_group: age_group,
        }
      end
    end

    def patients_in_access_point(patients, facility)
      patients.select { |q| q["access_point"] == facility }
    end

    def fetch_status_data
      query = his_patients.joins(<<-SQL)
                INNER JOIN concept_name hiv_status ON hiv_status.concept_id = obs.concept_id
                SQL
        .where(hiv_status: { name: "Hiv status" })
        .distinct
        .select("disaggregated_age_group(person.birthdate, '#{@end_date.to_date}') as age_group, person.person_id, person.gender, obs.value_coded as status")
        .to_sql
      Patient.connection.select_all(query).to_hash
    end

    # TODO: combine the queries later
    def fetch_facility_data
      query = his_patients
        .joins(<<-SQL)
        INNER JOIN concept_name facility ON facility.concept_id = obs.concept_id
        SQL
        .where(facility: { name: "Location where test took place" })
        .distinct
        .select("person.person_id, person.gender, person.birthdate, facility.name, obs.value_text as access_point")
        .to_sql
      Person.connection.select_all(query).to_hash
    end
  end
end
