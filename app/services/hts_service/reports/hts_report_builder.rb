module HtsService
  module Reports
    module HtsReportBuilder
      include HtsService::Reports::HtsAgeGroups

      HTC_PROGRAM = Program.find_by_name("HTC PROGRAM").id
      HIV_TESTING_ENCOUNTER = EncounterType.find_by_name("Testing")
      HIV_POSITIVE = concept("Positive").concept_id
      HIV_NEGATIVE = concept("Negative").concept_id
      HIV_STATUS_OBS = concept("HIV status").concept_id
      TEST_LOCATION = concept("Location where test took place").concept_id
      LINKED_CONCEPT = concept("Linked").concept_id
      OUTCOME_FACILITY = concept("ART clinic location").concept_id
      ART_OUTCOME = concept("Antiretroviral status or outcome").concept_id
      REFERRALS_ORDERED = concept("Referrals ordered").concept_id
      CURRENT_FACILITY = Location.find(GlobalProperty.find_by_property("current_health_center_id").property_value.to_i).name

      def his_patients
        Patient.joins(:person, encounters: [:observations, :program])
          .where(
            encounter: {
              encounter_datetime: @start_date..@end_date,
              encounter_type: HIV_TESTING_ENCOUNTER,
            },
            program: { program_id: HTC_PROGRAM },
          )
      end

      def all(query)
        query
      end

      def same_facility(patients)
        linked(patients)
          .merge(
            Patient.joins(<<-SQL)
              INNER JOIN obs within ON within.voided = 0 AND within.person_id = patient.patient_id
            SQL
              .where(
                within: { concept_id: OUTCOME_FACILITY, value_text: CURRENT_FACILITY },
              )
          )
      end

      def other_facilities(patients)
        linked(patients)
          .merge(
            Patient.joins(<<-SQL)
              INNER JOIN obs outside ON outside.voided = 0 AND outside.person_id = patient.patient_id
            SQL
              .where(
                outside: { concept_id: OUTCOME_FACILITY },
              )
          ).where.not(
                outside: { value_text: [CURRENT_FACILITY, nil] },
              )
      end

      def refered_outside(patients)
        patients
          .merge(
            Patient.joins(<<-SQL)
              INNER JOIN obs referred ON referred.voided = 0 AND referred.person_id = patient.patient_id
            SQL
              .where(
                referred: { concept_id: REFERRALS_ORDERED },
              )
          ).where.not(
                referred: { value_text: ["None", nil] },
              )
      end

      def male(patients)
        patients.where(person: { gender: "M" })
      end

      def female(patients)
        patients.where(person: { gender: "F" })
      end

      def tested_for_hiv(patients)
        patients.where(obs: { concept_id: HIV_STATUS_OBS })
      end

      def hiv_positive(patients)
        patients.where(obs: { value_coded: HIV_POSITIVE })
      end

      def hiv_negative(patients)
        patients.where(obs: { value_coded: HIV_NEGATIVE })
      end

      def test_location(patients, location)
        patients.merge(Patient.joins(person: :observations).where(
          observations_encounter: {
            concept_id: TEST_LOCATION, value_text: location,
          },
        ))
      end

      def linked(patients)
        patients.merge(Patient.joins(<<-SQL)
              INNER JOIN obs linked ON linked.voided = 0 AND linked.person_id = patient.patient_id
         SQL
          .where(
            linked: { concept_id: ART_OUTCOME, value_coded: LINKED_CONCEPT },
          ))
      end

      def htc(patients)
        test_location patients, "HTC"
      end

      def vct(patients)
        test_location patients, "VCT"
      end

      def opd(patients)
        test_location patients, "OPD"
      end

      def mch(patients)
        test_location patients, "Malnutrition"
      end

      def outreach(patients)
        test_location patients, "Mobile"
      end

      def anc(patients)
        test_location patients, "ANC First Visit"
      end
    end
  end
end
