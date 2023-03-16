module HtsService
  module Reports
    module HtsReportBuilder
      HTC_PROGRAM = Program.find_by_name("HTC PROGRAM").id
      HIV_TESTING_ENCOUNTER = EncounterType.find_by_name("Testing")
      ITEMS_GIVEN_ENCOUNTER = EncounterType.find_by_name("ITEMS GIVEN")
      HIV_POSITIVE = concept("Positive").concept_id
      HIV_NEGATIVE = concept("Negative").concept_id
      HIV_STATUS_OBS = concept("HIV status").concept_id
      TEST_LOCATION = concept("Location where test took place").concept_id
      VISIT_TYPE = concept("Visit type").concept_id
      SELF_TEST_DISTRIBUTION = concept("Self test distribution").concept_id
      LINKED_CONCEPT = concept("Linked").concept_id
      OUTCOME_FACILITY = concept("ART clinic location").concept_id
      ART_OUTCOME = concept("Antiretroviral status or outcome").concept_id
      REFERRALS_ORDERED = concept("Referrals ordered").concept_id
      CURRENT_FACILITY = Location.find(GlobalProperty.find_by_property("current_health_center_id").property_value.to_i).name

      def hts_age_groups
        [
          { less_than_one: "<1 year" },
          { one_to_four: "1-4 years" },
          { five_to_nine: "5-9 years" },
          { ten_to_fourteen: "10-14 years" },
          { fifteen_to_nineteen: "15-19 years" },
          { twenty_to_twenty_four: "20-24 years" },
          { twenty_five_to_twenty_nine: "25-29 years" },
          { thirty_to_thirty_four: "30-34 years" },
          { thirty_five_to_thirty_nine: "35-39 years" },
          { fourty_to_fourty_four: "40-44 years" },
          { fourty_five_to_fourty_nine: "45-49 years" },
          { fifty_to_fifty_four: "50-54 years" },
          { fifty_five_to_fifty_nine: "55-59 years" },
          { sixty_to_sixty_four: "60-64 years" },
          { sixty_five_to_sixty_nine: "65-69 years" },
          { seventy_to_seventy_four: "70-74 years" },
          { seventy_five_to_seventy_nine: "75-79 years" },
          { eighty_to_eighty_four: "80-84 years" },
          { eighty_five_to_eighty_nine: "85-89 years" },
          { ninety_plus: "90 plus years" },
        ].freeze
      end

      def his_patients_rev
        Patient.joins(:person, encounters: :program)
          .where(
            encounter: {
              encounter_datetime: @start_date..@end_date,
              encounter_type: HIV_TESTING_ENCOUNTER,
            },
            program: { program_id: HTC_PROGRAM },
          )
      end

      def self_test_clients
        Patient.joins(:person, encounters: [:observations, :program])
          .merge(
            Patient.joins(<<-SQL)
          INNER JOIN encounter test ON test.voided = 0 AND test.patient_id = patient.patient_id
          INNER JOIN obs visit ON visit.voided = 0 AND visit.person_id = person.person_id
          SQL
          )
          .where(
            visit: { concept_id: VISIT_TYPE, value_coded: SELF_TEST_DISTRIBUTION },
            encounter: {
              encounter_datetime: @start_date..@end_date,
              encounter_type: ITEMS_GIVEN_ENCOUNTER,
            },
            program: { program_id: HTC_PROGRAM },
          )
      end
    end
  end
end
