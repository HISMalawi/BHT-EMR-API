module HtsService
  module Reports
    module HtsReportBuilder

      HTC_PROGRAM = Program.find_by_name('HTC PROGRAM').id
      HIV_POSITIVE = concept('Positive').concept_id
      HIV_NEGATIVE = concept('Negative').concept_id
      HIV_STATUS_OBS = concept('HIV status').concept_id
      TEST_LOCATION = concept('Location where test took place').concept_id
      HIV_TESTING_ENCOUNTER = EncounterType.find_by_name('Testing')

      def his_patients
          Patient.joins(:person, encounters: [:observations, :program])
            .where(
              encounter: {
                encounter_datetime: @start_date..@end_date,
                encounter_type: HIV_TESTING_ENCOUNTER
              },
              program: { program_id: HTC_PROGRAM }
            )
      end

      def male patients
        patients.where(person: {gender:  'M'})
      end

      def female patients
        patients.where(person: {gender:  'F'})
      end

      def zero_to_nine patients
        patients.where(person: {birthdate: 9.years.ago..Date.today})
      end

      def ten_to_nineteen patients
        patients.where(person: {birthdate: 19.years.ago..10.years.ago})
      end

      def twenty_plus patients
        patients.where.not(person: {birthdate: 20.years.ago..Float::INFINITY})
      end

      def tested_for_hiv patients
        patients.where(obs: { concept_id: HIV_STATUS_OBS })
      end

      def hiv_positive patients
        patients.where(obs: { value_coded: HIV_POSITIVE })
      end

      def hiv_negative patients
        patients.where(obs: { value_coded: HIV_NEGATIVE })
      end

      def test_location patients, location
        patients.merge(Patient.joins(person: :observations).where(
          observations_encounter: {
            concept_id: TEST_LOCATION, value_text: location
          }
        ))
      end

      def htc patients
        test_location patients, 'HTC'
      end

      def vct patients
        test_location patients, 'VCT'
      end

      def opd patients
        test_location patients, 'OPD'
      end

      # def mch patients
      #   test_location patients, 'MCH'
      # end

      # def outreach patients
      #   test_location patients, 'Outreach'
      # end

      # def anc patients
      #   test_location patients, 'ANC First Visit'
      # end

    end
  end
end