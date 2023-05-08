module HtsService::Reports::Clinic
  class HtsLegacyReturning
    include HtsService::Reports::HtsReportBuilder
    attr_reader :start_date, :end_date, :report

    def initialize(start_date:, end_date:)
      @start_date = start_date.to_date.beginning_of_day
      @end_date = end_date.to_date.end_of_day
      @report = {}
      @returning_clients = ->(data) {
        data.where(
          prev_test: {
            value_coded: concept("Self").concept_id,
          },
        )
      }
    end

    def data
      init_report
    end

    private

    def init_report
      access_type_and_age_group
      last_tested
      partner_present
      outcome_summary
      result_given_to_client
      report.keys.each do |key|
        data = report.delete(key)
        report["community_#{key}"] = data.select { |q| q["access_type"] == "Community" }.map { |q| q["person_id"] }
        report["facility_#{key}"] = data.select { |q| q["access_type"] == "Health facility" }.map { |q| q["person_id"] }
      end
      report
    end

    def result_given_to_client
      data = Person.connection.select_all(
        query.joins(
          "
          INNER JOIN obs result_given ON result_given.person_id = person.person_id
          AND result_given.concept_id = #{concept("HIV group").concept_id}
          AND result_given.voided = 0
          INNER JOIN concept_name result_given_name ON result_given_name.concept_id = result_given.value_coded
          AND result_given_name.voided = 0
          "
        ).select("result_given_name.name as result_given")
      ).to_hash
      report[:new_negative_male] = data.select { |q| q["result_given"] == "New Negative" && q["gender"] == "M" }
      report[:new_negative_female] = data.select { |q| q["result_given"] == "New Negative" && q["gender"] == "F" }
      report[:new_positive_male] = data.select { |q| q["result_given"] == "New Positive" && q["gender"] == "M" }
      report[:new_positive_female] = data.select { |q| q["result_given"] == "New Positive" && q["gender"] == "F" }

      report[:new_exposed_infact] = data.select { |q| q["result_given"] == "New exposed infant" }
      report[:new_incoclusive] = data.select { |q| q["result_given"] == "New Inconclusive" }
      report[:confirmatory_positive_female] = data.select { |q| q["result_given"] == "Confirmatory Positive" && q["gender"] == "F" }
      report[:confirmatory_positive_male] = data.select { |q| q["result_given"] == "Confirmatory Positive" && q["gender"] == "M" }
      report[:confirmatory_positive_male] = data.select { |q| q["result_given"] == "Confirmatory Inconclusive" }
    end

    def outcome_summary
      data = Person.connection.select_all(
        query.joins(
          "INNER JOIN obs test_one ON test_one.person_id = person.person_id
          AND test_one.concept_id = #{concept("Test 1").concept_id}
          AND test_one.voided = 0
          INNER JOIN obs test_two ON test_two.person_id = person.person_id
          AND test_two.concept_id = #{concept("Test 1").concept_id}
          AND test_two.voided = 0
          INNER JOIN obs test_three ON test_three.person_id = person.person_id
          AND test_three.concept_id = #{concept("Test 3").concept_id}
          AND test_three.voided = 0"
        ).select("test_one.value_coded as test_one, test_two.value_coded as test_two, test_three.value_coded as test_three")
      ).to_hash
      report[:single_negative] = data.select { |q| q["test_one"] == concept("Negative").concept_id }
      report[:single_positive] = data.select { |q| q["test_one"] == concept("Positive").concept_id }
      report[:one_and_two_positive] = data.select { |q| q["test_one"] == concept("Negative").concept_id }
      report[:one_and_two_negative] = data.select { |q| q["test_one"] == concept("Negative").concept_id }
      report[:one_and_two_disc] = data.select { |q| q["test_one"] == concept("Positive").concept_id }
    end

    def partner_present
      data = Person.connection.select_all(
        query.joins(
          "INNER JOIN obs partner_present ON partner_present.person_id = person.person_id
          AND partner_present.concept_id = #{concept("Partner present").concept_id}
          AND partner_present.voided = 0"
        ).select("partner_present.value_text as partner_present")
      ).to_hash
      report[:partner_present] = data.select { |q| q["partner_present"] == "Yes" }
      report[:partner_not_present] = data.select { |q| q["partner_present"] == "No" }
    end

    def last_tested
      data = Person.connection.select_all(
        query.joins(
          "INNER JOIN obs last_tested ON last_tested.person_id = person.person_id
          AND last_tested.concept_id = #{concept("Previous HIV Test Results").concept_id}
          AND last_tested.voided = 0"
        ).select("last_tested.value_coded as last_tested")
      ).to_hash
      report[:last_never_tested] = data.select { |q| q["last_tested"] == HIV_NEVER_TESTED }
      report[:last_negative] = data.select { |q| q["last_tested"] == HIV_NEGATIVE }
      report[:last_positive] = data.select { |q| q["last_tested"] == HIV_POSITIVE }
      report[:last_exposed_infant] = data.select { |q| q["last_tested"] == HIV_EXPOSED_INFANT }
      report[:last_inconclusive] = data.select { |q| q["last_tested"] == HIV_INVALID_OR_INCONCLUSIVE }
    end

    def access_type_and_age_group
      data = Person.connection.select_all(
        query.joins(
          "INNER JOIN obs test_location ON test_location.person_id = person.person_id
          AND test_location.concept_id = #{TEST_LOCATION}
          AND test_location.voided = 0

          LEFT JOIN obs p_status ON p_status.person_id = person.person_id
          AND p_status.concept_id = #{concept("Pregnancy status").concept_id}
          AND p_status.voided = 0
          LEFT JOIN concept_name p_status_name ON p_status_name.concept_id = p_status.value_coded
          AND p_status_name.voided = 0
          "
        ).select("test_location.value_text as test_location, person.birthdate, p_status_name.name as status")
      ).to_hash
      report[:pict] = data.select { |q| q["test_location"] == "Other PITC" }
      report[:frs] = data.select { |q| q["test_location"] == "FRS" }
      report[:other] = data.select { |q| !["Other PITC", "FRS"].include?(q["test_location"]) }

      report[:twenty_five_plus] = data.select { |q| birthdate_to_age(q["birthdate"]) > 25 }
      report[:zero_to_eleven_months] = data.select { |q| birthdate_to_age(q["birthdate"]) < 1 }
      report[:one_to_fourteen_years] = data.select { |q| (1..14).include?(birthdate_to_age(q["birthdate"])) }
      report[:fiveteen_to_twenty_four_years] = data.select { |q| (15..24).include?(birthdate_to_age(q["birthdate"])) }

      report[:male] = data.select { |q| q["gender"] == "M" }
      report[:fnp] = data.select { |q| ["Not Pregnant / Breastfeeding", "Breastfeeding"].include?(q["status"]) }
      report[:fp] = data.select { |q| q["status"] == "Pregnant woman" }
    end

    def birthdate_to_age(birthdate)
      today = Date.today
      age = today.year - birthdate.year
      age
    end

    def query
      data = his_patients_rev
        .joins(
          "INNER JOIN obs location ON location.concept_id = #{HTS_ACCESS_TYPE}
        AND location.voided = 0
        AND location.person_id = person.person_id
        INNER JOIN concept_name access_type_name ON access_type_name.concept_id = location.value_coded
        AND access_type_name.voided = 0
        LEFT JOIN obs prev_test ON prev_test.concept_id = #{concept("Previous HIV test done").concept_id}
        AND prev_test.voided = 0
        AND prev_test.person_id = person.person_id
        "
        )
      @returning_clients.call(data).select("access_type_name.name as access_type, person.person_id, person.gender")
    end
  end
end
