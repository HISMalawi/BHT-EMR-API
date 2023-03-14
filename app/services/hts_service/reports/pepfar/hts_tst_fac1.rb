module HtsService::Reports::Pepfar
  # HTS_TST_Fac1 report
  class HtsTstFac1
    include HtsService::Reports::HtsReportBuilder
    attr_reader :start_date, :end_date, :report, :numbering

    ACCESS_POINTS = %i[index emergency inpatient malnutrition pediatric pmtct_anc1]

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
      x = send("array_#{age_group.keys.first}", data).deep_dup
      y = {
        pos: x.select { |q| q["value_coded"] == HIV_POSITIVE }.map { |q| q["person_id"] },
        neg: x.select { |q| q["value_coded"] == HIV_NEGATIVE }.map { |q| q["person_id"] },
      }
      y
    end

    def calc_access_points(data, row)
      ACCESS_POINTS.each do |access_point|
        x = send("filter_#{access_point}", data)
        row["#{access_point}"] = calc_age_groups(x.select { |q| q["gender"] == row[:gender].to_s.strip }, row[:age_group])
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

    def filter_index(patients)
      has_facility(patients, "Index")
    end

    def filter_emergency(patients)
      has_facility(patients, "Emergency")
    end

    def filter_inpatient(patients)
      has_facility(patients, "Inpatient")
    end

    def filter_malnutrition(patients)
      has_facility(patients, "Malnutrition")
    end

    def filter_pediatric(patients)
      has_facility(patients, "Pediatric")
    end

    def filter_pmtct_anc1(patients)
      has_facility(patients, "ANC first visit")
    end

    def has_facility(patients, facility)
      patients.select { |q| q["value_text"] == facility }
    end

    def fetch_status_data
      query = his_patients.joins(<<-SQL)
                INNER JOIN concept_name hiv_status ON hiv_status.concept_id = obs.concept_id
                SQL
        .where(hiv_status: { name: "Hiv status" })
        .distinct
        .select("person.person_id, person.gender, person.birthdate, hiv_status.name, obs.value_coded")
        .to_sql
      Patient.connection.select_all(query).to_hash
    end

    def fetch_facility_data
      query = his_patients
        .joins(<<-SQL)
        INNER JOIN concept_name facility ON facility.concept_id = obs.concept_id
        SQL
        .where(facility: { name: "Location where test took place" })
        .distinct
        .select("person.person_id, person.gender, person.birthdate, facility.name, obs.value_text")
        .to_sql
      Person.connection.select_all(query).to_hash
    end

    def array_less_than_one(patients)
      patients.select { |q| age(q["birthdate"]) < 1 }
    end

    def array_one_to_four(patients)
      select_range(1, 4, patients)
    end

    def array_five_to_nine(patients)
      select_range(5, 9, patients)
    end

    def array_ten_to_fourteen(patients)
      select_range(10, 14, patients)
    end

    def array_fifteen_to_nineteen(patients)
      select_range(15, 19, patients)
    end

    def array_twenty_to_twenty_four(patients)
      select_range(20, 24, patients)
    end

    def array_twenty_five_to_twenty_nine(patients)
      select_range(25, 29, patients)
    end

    def array_thirty_to_thirty_four(patients)
      select_range(30, 34, patients)
    end

    def array_thirty_five_to_thirty_nine(patients)
      select_range(35, 39, patients)
    end

    def array_fourty_to_fourty_four(patients)
      select_range(40, 49, patients)
    end

    def array_fourty_five_to_fourty_nine(patients)
      select_range(45, 49, patients)
    end

    def array_fifty_to_fifty_four(patients)
      select_range(50, 54, patients)
    end

    def array_fifty_five_to_fifty_nine(patients)
      select_range(55, 59, patients)
    end

    def array_sixty_to_sixty_four(patients)
      select_range(60, 64, patients)
    end

    def array_sixty_five_to_sixty_nine(patients)
      select_range(1, 4, patients)
    end

    def array_seventy_to_seventy_four(patients)
      select_range(70, 74, patients)
    end

    def array_seventy_five_to_seventy_nine(patients)
      select_range(75, 79, patients)
    end

    def array_eighty_to_eighty_four(patients)
      select_range(80, 84, patients)
    end

    def array_eighty_five_to_eighty_nine(patients)
      select_range(85, 89, patients)
    end

    def array_ninety_plus(patients)
      patients.select { |q| age(q["birthdate"]) > 90 }
    end

    def select_range(start, finish, patients)
      patients.select { |q| (start..finish).include?(age(q["birthdate"])) }
    end

    def age(birthdate)
      ((Date.today.to_date - birthdate.to_date) / 365.25).to_i + 1
    end
  end
end
