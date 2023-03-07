module HtsService::Reports::Moh
  class HtsSelfTestSummary
    include HtsService::Reports::HtsReportBuilder
    attr_accessor :start_date, :end_date, :data

    FACILITY = %i[total_recipients_at_the_facility facility_vct facility_anc_first_visit facility_inpatient facility_sti facility_pmtctfup facility_index facility_paediatric facility_vmmc facility_malnutrition facility_tb facility_opd facility_other_pitc facility_sns].freeze
    COMMUNITY = %i[total_recipients_in_the_community community_vmmc community_index community_mobile community_vct community_other community_sns].freeze
    GENDER = %i[female_non_pregnant female_pregnant male].freeze
    SEX = %i[male female].freeze
    AGE_GROUPS = %i[less_than_13 13_to_14 15_to_19 20_to_24 25_to_29 30_to_34 35_to_39 40_to_44 45_to_49 50_plus]
    LAST_HIV_TEST = %i[never_tested negative positive_on_art positive_not_on_art inconclusive].freeze
    LAST_SICE_HIV_TEST = %i[twelve_plus_months six_to_eleven_months thirty_five_months fourteen_days_to_two_months one_to_thirteen_days same_day].freeze
    CONDOMS_GIVEN = %i[condoms_sum]

    def initialize(start_date:, end_date:)
      @start_date = start_date.to_date.beginning_of_day
      @end_date = end_date.to_date.end_of_day
      @data = {}
    end

    def data
      init_report
    end

    private

    def init_report
      calc_facility_data self_test_clients
      calc_community_data self_test_clients
      calc_gender_types self_test_clients
      calc_groups self_test_clients
      calc_last_hiv_test self_test_clients
      calc_items_given self_test_clients
      calc_test_kit_end_users self_test_clients
      calc_end_user_sex_and_age self_test_clients

      @data
    end

    private

    def calc_facility_data(clients)
      FACILITY.each { |indicator| @data[indicator] = [] }
      @data[:total_recipients] = @data[:total_recipients] + 0 rescue 0
      access_type(clients, "Health Facility").where(obs: { concept_id: TEST_LOCATION })
        .distinct
        .select("obs.value_text, patient.patient_id")
        .each do |client|
        @data[:total_recipients] += 1
        @data[:total_recipients_at_the_facility].push(client.patient_id)
        @data[:facility_vct].push(client.patient_id) if client.value_text == "VCT"
        @data[:facility_anc_first_visit].push(client.patient_id) if client.value_text == "ANC First Visit"
        @data[:facility_inpatient].push(client.patient_id) if client.value_text == "Inpatient"
        @data[:facility_sti].push(client.patient_id) if client.value_text == "STI"
        @data[:facility_pmtctfup].push(client.patient_id) if client.value_text == "PMTCT FUP"
        @data[:facility_index].push(client.patient_id) if client.value_text == "Index"
        @data[:facility_paediatric].push(client.patient_id) if client.value_text == "Paediatric"
        @data[:facility_vmmc].push(client.patient_id) if client.value_text == "VMMC"
        @data[:facility_malnutrition].push(client.patient_id) if client.value_text == "Malnutrition"
        @data[:facility_tb].push(client.patient_id) if client.value_text == "TB"
        @data[:facility_opd].push(client.patient_id) if client.value_text == "OPD"
        @data[:facility_other_pitc].push(client.patient_id) if client.value_text == "Other PITC"
        @data[:facility_sns].push(client.patient_id) if client.value_text == "SNS"
      end
    end

    def calc_community_data(clients)
      COMMUNITY.each { |indicator| @data[indicator] = [] }
      access_type(clients, "Community").where(obs: { concept_id: TEST_LOCATION })
        .distinct
        .select("obs.value_text, patient.patient_id")
        .each do |client|
        @data[:total_recipients] += 1
        @data[:total_recipients_in_the_community].push(client.patient_id)
        @data[:community_vmmc].push(client.patient_id) if client.value_text == "VMMC"
        @data[:community_index].push(client.patient_id) if client.value_text == "Index"
        @data[:community_mobile].push(client.patient_id) if client.value_text == "Mobile"
        @data[:community_vct].push(client.patient_id) if client.value_text == "VCT"
        @data[:community_other].push(client.patient_id) if client.value_text == "Other"
        @data[:community_sns].push(client.patient_id) if client.value_text == "SNS"
      end
    end

    def calc_gender_types(clients)
      GENDER.each { |indicator| @data[indicator] = [] }
      clients.where(obs: { concept_id: ConceptName.find_by_name("Pregnancy status").concept_id })
        .distinct
        .select("obs.value_coded, patient.patient_id, person.gender")
        .each do |client|
        @data[:female_non_pregnant].push(client.id) if client.value_coded == 9538
        @data[:female_pregnant].push(client.id) if client.value_coded == 1755
        @data[:male].push(client.id) if client.gender == "M"
      end
    end

    def calc_groups(clients)
      SEX.each do |sex|
        AGE_GROUPS.each { |age_group| @data["#{sex}s_#{age_group}"] = [] }
      end
      clients
        .distinct
        .select("patient.patient_id, person.birthdate, person.gender")
        .each do |client|
        SEX.each do |sex|
          @data["#{sex}s_less_than_13"].push(client.id) if client.gender == sex[0].humanize && dob_within(client.birthdate, 0, 12)
          @data["#{sex}s_13_to_14"].push(client.id) if client.gender == sex[0].humanize && dob_within(client.birthdate, 13, 14)
          @data["#{sex}s_15_to_19"].push(client.id) if client.gender == sex[0].humanize && dob_within(client.birthdate, 15, 19)
          @data["#{sex}s_20_to_24"].push(client.id) if client.gender == sex[0].humanize && dob_within(client.birthdate, 20, 24)
          @data["#{sex}s_25_to_29"].push(client.id) if client.gender == sex[0].humanize && dob_within(client.birthdate, 25, 29)
          @data["#{sex}s_30_to_34"].push(client.id) if client.gender == sex[0].humanize && dob_within(client.birthdate, 30, 34)
          @data["#{sex}s_35_to_39"].push(client.id) if client.gender == sex[0].humanize && dob_within(client.birthdate, 35, 39)
          @data["#{sex}s_40_to_44"].push(client.id) if client.gender == sex[0].humanize && dob_within(client.birthdate, 40, 44)
          @data["#{sex}s_45_to_49"].push(client.id) if client.gender == sex[0].humanize && dob_within(client.birthdate, 45, 49)
          @data["#{sex}s_50_plus"].push(client.id) if client.gender == sex[0].humanize && dob_within(client.birthdate, 50, 120)
        end
      end
    end

    def calc_last_hiv_test(clients)
      LAST_HIV_TEST.each { |indicator| @data[indicator] = [] }
      clients
        .where(obs: { concept_id: ConceptName.find_by_name("Previous HIV Test Results").concept_id })
        .distinct
        .select("obs.value_coded, patient.patient_id")
        .each do |client|
        @data[:positive_not_on_art].push(client) if client.value_coded == concept("Positive not on ART").id
        @data[:positive_on_art].push(client.patient_id) if client.value_coded == concept("Positive on ART").id
        @data[:negative].push(client.patient_id) if client.value_coded == concept("Negative").id
        @data[:never_tested].push(client.patient_id) if client.value_coded == concept("Never Tested").id
        @data[:inconclusive].push(client.patient_id) if client.value_coded == concept("Inconclusive").id
      end
    end

    def calc_time_since_last_hiv_result(clients)
      clients.where(obs: { concept_id: ConceptName.find_by_name("Time of HIV test").concept_id })
        .distinct
        .select("obs.value_datetime, patient.patient_id")
        .each do |client|
        @data[:last_hiv_result_12_plus_months].push(client.patient_id) if client.value_datetime >= 12.months.ago
        @data[:last_hiv_result_6_to_11_months].push(client.patient_id) if client.value_datetime >= 6.months.ago && client.value_datetime <= 11.months.ago
        @data[:last_hiv_result_3_to_5_months].push(client.patient_id) if client.value_datetime >= 3.months.ago && client.value_datetime <= 5.months.ago
        @data[:last_hiv_result_14_days_to_2_months].push(client.patient_id) if client.value_datetime >= 14.days.ago && client.value_datetime <= 2.months.ago
        @data[:last_hiv_result_1_to_13_days].push(client.patient_id) if client.value_datetime >= 1.day.ago && client.value_datetime <= 13.days.ago
      end
    end

    def calc_items_given(clients)
      @data[:female_condoms_sum] = 0
      @data[:male_condoms_sum] = 0
      clients.joins(<<-SQL)
       INNER JOIN concept_name on concept_name.concept_id = obs.concept_id
       SQL
        .where(
          concept_name: { name: ["Female condoms", "Male condoms"] },
        )
        .pluck("obs.value_numeric, concept_name.name")
        .each do |client|
        @data[:female_condoms_sum] += client[0].to_i if client[1] == "Female condoms"
        @data[:male_condoms_sum] += client[0].to_i if client[1] == "Male condoms"
      end
    end

    def calc_test_kit_end_users(clients)
      @data[:self] = 0
      @data[:sexpartner] = 0
      @data[:other] = 0
      clients.joins(<<-SQL)
        INNER JOIN concept_name on concept_name.concept_id = obs.concept_id
        SQL
        .where(
          concept_name: { name: "Self-Test end user" },
        )
        .distinct
        .pluck("obs.value_coded")
        .each do |client|
        puts client
        @data[:self] += 1 if client == concept("Self").id
        @data[:sexpartner] += 1 if client == concept("Sexual Partner").id
        @data[:other] += 1 if client == concept("Other").id
      end
    end

    def calc_end_user_sex_and_age(clients)
      SEX.each do |sex|
        AGE_GROUPS.each { |age_group| @data["end_user_#{sex}s_#{age_group}"] = 0 }
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
          @data["end_user_#{sex}s_less_than_13"] += 1 if age_within(client.value_numeric, 0, 12) && gender_is_right(sex, client.obs_group_id)
          @data["end_user_#{sex}s_13_to_14"] += 1 if age_within(client.value_numeric, 13, 14) && gender_is_right(sex, client.obs_group_id)
          @data["end_user_#{sex}s_15_to_19"] += 1 if age_within(client.value_numeric, 15, 19) && gender_is_right(sex, client.obs_group_id)
          @data["end_user_#{sex}s_20_to_24"] += 1 if age_within(client.value_numeric, 20, 24) && gender_is_right(sex, client.obs_group_id)
          @data["end_user_#{sex}s_25_to_29"] += 1 if age_within(client.value_numeric, 25, 29) && gender_is_right(sex, client.obs_group_id)
          @data["end_user_#{sex}s_30_to_34"] += 1 if age_within(client.value_numeric, 30, 34) && gender_is_right(sex, client.obs_group_id)
          @data["end_user_#{sex}s_35_to_39"] += 1 if age_within(client.value_numeric, 35, 39) && gender_is_right(sex, client.obs_group_id)
          @data["end_user_#{sex}s_40_to_44"] += 1 if age_within(client.value_numeric, 40, 44) && gender_is_right(sex, client.obs_group_id)
          @data["end_user_#{sex}s_45_to_49"] += 1 if age_within(client.value_numeric, 45, 49) && gender_is_right(sex, client.obs_group_id)
          @data["end_user_#{sex}s_50_plus"] += 1 if age_within(client.value_numeric, 50, 120) && gender_is_right(sex, client.obs_group_id)
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
      obs = Observation.where(obs_group_id: obs_group_id, concept_id: concept("Gender of contact")).first.value_coded == concept(gender).id
    end

    def age_within(age, min, max)
      (min..max).include?(age)
    end

    def dob_within(birthdate, min, max)
      age = ((Date.today.to_date - birthdate.to_date) / 365.25).to_i
      (min..max).include?(age)
    end
  end
end
