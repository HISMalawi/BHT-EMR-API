module HtsService::Reports::Clinic
  class HtsLink
    include HtsService::Reports::HtsReportBuilder
    attr_reader :start_date, :end_date

    INDICATORS = %i[same_facility other_facilities].freeze
    AGE_GROUPS = %i[zero_to_nine ten_to_nineteen twenty_plus].freeze
    LINKED_DAYS = %i[same_day two_to_seven_days eight_to_twenty_eight_days twenty_eight_days_plus].freeze
    GENDER = %i[male female].freeze

    def initialize(start_date:, end_date:)
      @start_date = start_date.to_date.beginning_of_day
      @end_date = end_date.to_date.end_of_day
    end

    def data
      init_report
    end

    private

    def init_report
      report = []
      GENDER.each do |gender|
        hts_age_groups.each_with_object([]) do |age_group, index|
          obj = {}
          INDICATORS.each do |indicator|
            obj[indicator.to_s] = {}
            obj["gender"] = gender[0].upcase
            obj["age_group"] = age_group.values.first
            LINKED_DAYS.each do |linked_day|
              puts "Searching for #{gender.to_s.capitalize} #{age_group.values.first}  #{indicator.to_s.humanize} Within #{linked_day.to_s.humanize}"
              query = [age_group.keys.first.to_s, gender.to_s, linked_day.to_s, indicator.to_s].inject(his_patients) do |result, method|
                send method, result
              end
              obj[indicator.to_s][linked_day.to_s] = query.distinct.pluck(:patient_id)
            end
          end
          report << obj
        end
      end
      report
    end

    def same_day(patients)
      patients.where("DATE(linked.obs_datetime) = DATE(encounter.encounter_datetime)")
    end

    def two_to_seven_days(patients)
      patients.where("DATE(linked.obs_datetime) BETWEEN DATE(encounter.encounter_datetime) + INTERVAL 1 DAY AND DATE(encounter.encounter_datetime) + INTERVAL 6 DAY")
    end

    def eight_to_twenty_eight_days(patients)
      patients.where("DATE(linked.obs_datetime) BETWEEN DATE(encounter.encounter_datetime) + INTERVAL 7 DAY AND DATE(encounter.encounter_datetime) + INTERVAL 27 DAY")
    end

    def twenty_eight_days_plus(patients)
      patients.where("DATE(linked.obs_datetime) > DATE(encounter.encounter_datetime) + INTERVAL 28 DAY")
    end
  end
end
