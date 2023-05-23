module HtsService::Reports::Moh
  class HtsSelfTestSummary
    include HtsService::Reports::HtsReportBuilder
    attr_accessor :start_date, :end_date, :report

    FACILITY = %i[total_recipients_at_the_facility facility_vct facility_anc_first_visit facility_inpatient facility_sti facility_pmtctfup facility_index facility_paediatric facility_vmmc facility_malnutrition facility_tb facility_opd facility_other_pitc facility_sns].freeze
    COMMUNITY = %i[total_recipients_in_the_community community_vmmc community_index community_mobile community_vct community_other community_sns].freeze
    GENDER = %i[female_non_pregnant female_pregnant male].freeze
    SEX = %i[male female].freeze
    AGE_GROUPS = %i[less_than_13 13_to_14 15_to_19 20_to_24 25_to_29 30_to_34 35_to_39 40_to_44 45_to_49 50_plus]
    LAST_HIV_TEST = %i[never_tested negative positive_on_art positive_not_on_art inconclusive].freeze
    LAST_SICE_HIV_TEST = %i[twelve_plus_months six_to_eleven_months thirty_five_months fourteen_days_to_two_months one_to_thirteen_days same_day].freeze
    LAST_HIV_RESULT_DATE = %i[last_hiv_result_same_day last_hiv_result_12_plus_months last_hiv_result_1_to_13_days last_hiv_result_6_to_11_months last_hiv_result_3_to_5_months last_hiv_result_14_days_to_2_months last_hiv_result_less_than_14_days]
    CONDOMS_GIVEN = %i[condoms_sum]

    def initialize(start_date:, end_date:)
      @start_date = start_date.to_date.beginning_of_day
      @end_date = end_date.to_date.end_of_day
      @report = {}
    end

    def data
      init_report
    end

    private

    def init_report
      calc_facility_report self_test_clients
      calc_community_report self_test_clients
      calc_gender_types self_test_clients
      calc_groups self_test_clients
      calc_last_hiv_test self_test_clients
      calc_time_since_last_hiv_result self_test_clients
      calc_items_given self_test_clients
      calc_test_kit_end_users self_test_clients
      calc_end_user_sex_and_age self_test_clients
      report[:total_recipients] = self_test_clients.distinct.pluck(:patient_id)
      report["missing"] = []
      report["invalid_entry"] = []
      report["not_applicable_or_missing"] = []
      report
    end

    private

    def calc_facility_report(clients)
      FACILITY.each { |indicator| report[indicator] = [] }
      access_type(clients, "Health Facility").where(obs: { concept_id: TEST_LOCATION })
        .distinct
        .select("obs.value_text, patient.patient_id")
        .each do |client|
        report[:total_recipients_at_the_facility].push(client.patient_id)
        report[:facility_vct].push(client.patient_id) if client.value_text == "VCT"
        report[:facility_anc_first_visit].push(client.patient_id) if client.value_text == "ANC First Visit"
        report[:facility_inpatient].push(client.patient_id) if client.value_text == "Inpatient"
        report[:facility_sti].push(client.patient_id) if client.value_text == "STI"
        report[:facility_pmtctfup].push(client.patient_id) if client.value_text == "PMTCT FUP"
        report[:facility_index].push(client.patient_id) if client.value_text == "Index"
        report[:facility_paediatric].push(client.patient_id) if client.value_text == "Paediatric"
        report[:facility_vmmc].push(client.patient_id) if client.value_text == "VMMC"
        report[:facility_malnutrition].push(client.patient_id) if client.value_text == "Malnutrition"
        report[:facility_tb].push(client.patient_id) if client.value_text == "TB"
        report[:facility_opd].push(client.patient_id) if client.value_text == "OPD"
        report[:facility_other_pitc].push(client.patient_id) if client.value_text == "Other PITC"
        report[:facility_sns].push(client.patient_id) if client.value_text == "SNS"
      end
    end

    def calc_community_report(clients)
      COMMUNITY.each { |indicator| report[indicator] = [] }
      access_type(clients, "Community").where(obs: { concept_id: TEST_LOCATION })
        .distinct
        .select("obs.value_text, patient.patient_id")
        .each do |client|
        report[:total_recipients_in_the_community].push(client.patient_id)
        report[:community_vmmc].push(client.patient_id) if client.value_text == "VMMC"
        report[:community_index].push(client.patient_id) if client.value_text == "Index"
        report[:community_mobile].push(client.patient_id) if client.value_text == "Mobile"
        report[:community_vct].push(client.patient_id) if client.value_text == "VCT"
        report[:community_other].push(client.patient_id) if client.value_text == "Other"
        report[:community_sns].push(client.patient_id) if client.value_text == "SNS"
      end
    end

    def calc_gender_types(clients)
      GENDER.each { |indicator| report[indicator] = [] }
      clients.where(obs: { concept_id: ConceptName.find_by_name("Pregnancy status").concept_id })
        .distinct
        .select("obs.value_coded, patient.patient_id, person.gender")
        .each do |client|
        report[:female_non_pregnant].push(client.id) if [5632, 9538].include?(client.value_coded)
        report[:female_pregnant].push(client.id) if client.value_coded == 1755
      end
    end

    def calc_groups(clients)
      SEX.each do |sex|
        AGE_GROUPS.each { |age_group| report["#{sex}s_#{age_group}"] = [] }
      end
      clients
        .distinct
        .select("patient.patient_id, person.birthdate, person.gender")
        .each do |client|
        report[:male].push(client.id) if client.gender == "M"
        SEX.each do |sex|
          report["#{sex}s_less_than_13"].push(client.id) if client.gender == sex[0].humanize && dob_within(client.birthdate, 0, 12)
          report["#{sex}s_13_to_14"].push(client.id) if client.gender == sex[0].humanize && dob_within(client.birthdate, 13, 14)
          report["#{sex}s_15_to_19"].push(client.id) if client.gender == sex[0].humanize && dob_within(client.birthdate, 15, 19)
          report["#{sex}s_20_to_24"].push(client.id) if client.gender == sex[0].humanize && dob_within(client.birthdate, 20, 24)
          report["#{sex}s_25_to_29"].push(client.id) if client.gender == sex[0].humanize && dob_within(client.birthdate, 25, 29)
          report["#{sex}s_30_to_34"].push(client.id) if client.gender == sex[0].humanize && dob_within(client.birthdate, 30, 34)
          report["#{sex}s_35_to_39"].push(client.id) if client.gender == sex[0].humanize && dob_within(client.birthdate, 35, 39)
          report["#{sex}s_40_to_44"].push(client.id) if client.gender == sex[0].humanize && dob_within(client.birthdate, 40, 44)
          report["#{sex}s_45_to_49"].push(client.id) if client.gender == sex[0].humanize && dob_within(client.birthdate, 45, 49)
          report["#{sex}s_50_plus"].push(client.id) if client.gender == sex[0].humanize && dob_within(client.birthdate, 50, 120)
        end
      end
    end

    def calc_last_hiv_test(clients)
      LAST_HIV_TEST.each { |indicator| report[indicator] = [] }
      clients
        .where(obs: { concept_id: ConceptName.find_by_name("Previous HIV Test Results").concept_id })
        .distinct
        .select("obs.value_coded, patient.patient_id")
        .each do |client|
        report[:positive_not_on_art].push(client) if client.value_coded == concept("Positive not on ART").id
        report[:positive_on_art].push(client.patient_id) if client.value_coded == concept("Positive on ART").id
        report[:negative].push(client.patient_id) if client.value_coded == concept("Negative").id
        report[:never_tested].push(client.patient_id) if client.value_coded == concept("Never Tested").id
        report[:inconclusive].push(client.patient_id) if client.value_coded == concept("Inconclusive").id
      end
    end

    def calc_time_since_last_hiv_result(clients)
      LAST_HIV_RESULT_DATE.each { |indicator| report[indicator] = [] }
      clients.where(obs: { concept_id: ConceptName.find_by_name("Time of HIV test").concept_id })
        .distinct
        .select("obs.value_datetime, obs.obs_datetime, patient.patient_id")
        .each do |client|
        next if client.value_datetime.blank?
        report[:last_hiv_result_same_day].push(client.patient_id) if client.value_datetime <= 0.days.ago && client.value_datetime >= 1.day.ago
        report[:last_hiv_result_12_plus_months].push(client.patient_id) if client.value_datetime.to_date <= 12.months.ago
        report[:last_hiv_result_6_to_11_months].push(client.patient_id) if client.value_datetime <= 6.months.ago && client.value_datetime >= 11.months.ago
        report[:last_hiv_result_3_to_5_months].push(client.patient_id) if client.value_datetime <= 3.months.ago && client.value_datetime >= 5.months.ago
        report[:last_hiv_result_14_days_to_2_months].push(client.patient_id) if client.value_datetime <= 14.days.ago && client.value_datetime >= 2.months.ago
        report[:last_hiv_result_1_to_13_days].push(client.patient_id) if client.value_datetime <= 1.day.ago && client.value_datetime >= 13.days.ago
      end
    end

    def calc_items_given(clients)
      report[:female_condoms_sum] = 0
      report[:male_condoms_sum] = 0
      clients.joins(<<-SQL)
       INNER JOIN concept_name on concept_name.concept_id = obs.concept_id
       SQL
        .where(
          concept_name: { name: ["Female condoms", "Male condoms"] },
        )
        .pluck("obs.value_numeric, concept_name.name")
        .each do |client|
        report[:female_condoms_sum] += client[0].to_i if client[1] == "Female condoms"
        report[:male_condoms_sum] += client[0].to_i if client[1] == "Male condoms"
      end
    end

    def calc_test_kit_end_users(clients)
      report[:self] = 0
      report[:sexpartner] = 0
      report[:other] = 0
      report[:total_endusers] = 0
      clients.joins(<<-SQL)
        INNER JOIN concept_name on concept_name.concept_id = obs.concept_id
        SQL
        .where(
          concept_name: { name: "Self-Test end user" },
        )
        .pluck("obs.value_coded")
        .each do |client|
        report[:total_endusers] += 1
        report[:self] += 1 if client == concept("Self").id
        report[:sexpartner] += 1 if client == concept("Sexual Partner").id
        report[:other] += 1 if client == concept("Other").id
      end
    end

    def calc_end_user_sex_and_age(clients)
      SEX.each do |sex|
        AGE_GROUPS.each { |age_group| report["end_user_#{sex}s_#{age_group}"] = 0 }
        report["total_#{sex}_end_users"] = 0
      end
      clients.joins(<<-SQL)
      INNER JOIN concept_name on concept_name.concept_id = obs.concept_id
      SQL
        .where(
          concept_name: { name: "Age of contact" },
        )
        .distinct
        .select("obs.value_numeric, obs.obs_group_id, person.person_id")
        .each do |client|
        SEX.each do |sex|
          report["total_#{sex}_end_users"] +=1 if gender_is_right(sex, client.obs_group_id)
          report["end_user_#{sex}s_less_than_13"] += 1 if age_within(client.value_numeric, 0, 12) && gender_is_right(sex, client.obs_group_id)
          report["end_user_#{sex}s_13_to_14"] += 1 if age_within(client.value_numeric, 13, 14) && gender_is_right(sex, client.obs_group_id)
          report["end_user_#{sex}s_15_to_19"] += 1 if age_within(client.value_numeric, 15, 19) && gender_is_right(sex, client.obs_group_id)
          report["end_user_#{sex}s_20_to_24"] += 1 if age_within(client.value_numeric, 20, 24) && gender_is_right(sex, client.obs_group_id)
          report["end_user_#{sex}s_25_to_29"] += 1 if age_within(client.value_numeric, 25, 29) && gender_is_right(sex, client.obs_group_id)
          report["end_user_#{sex}s_30_to_34"] += 1 if age_within(client.value_numeric, 30, 34) && gender_is_right(sex, client.obs_group_id)
          report["end_user_#{sex}s_35_to_39"] += 1 if age_within(client.value_numeric, 35, 39) && gender_is_right(sex, client.obs_group_id)
          report["end_user_#{sex}s_40_to_44"] += 1 if age_within(client.value_numeric, 40, 44) && gender_is_right(sex, client.obs_group_id)
          report["end_user_#{sex}s_45_to_49"] += 1 if age_within(client.value_numeric, 45, 49) && gender_is_right(sex, client.obs_group_id)
          report["end_user_#{sex}s_50_plus"] += 1 if age_within(client.value_numeric, 50, 120) && gender_is_right(sex, client.obs_group_id)
        end
      end
    end

    def access_type(clients, type)
      clients.merge(
        Patient.joins(<<-SQL)
          INNER JOIN obs access_point ON access_point.person_id = patient.patient_id
          AND access_point.concept_id = #{ConceptName.find_by_name("HTS Access Type").concept_id}
          AND access_point.value_coded = #{ConceptName.find_by_name(type).concept_id}
          AND access_point.voided = 0
          SQL
      )
    end

    def gender_is_right(gender, obs_group_id)
      Observation.where(obs_group_id: obs_group_id, concept_id: concept("Gender of contact")).first.value_coded == concept(gender).id
    end

    def age_within(age, min, max)
      (min..max).include?(age)
    end

    def dob_within(birthdate, min, max)
      age = ((Date.today.to_date - birthdate.to_date) / 365.25).to_i+1
      age_within(age, min, max)
    end
  end
end
