# frozen_string_literal: true

module ARTService
  module Reports
    Constants = ARTService::Constants

    class RegimensByWeightAndAge
      attr_reader :start_date, :end_date

      def initialize(start_date:, end_date:, **_kwargs)
        @start_date = start_date
        @end_date = end_date
      end

      def find_report
        regimen_counts
      end

      private

      AGE_GROUPS = [
        [0, 5, :months],
        [6, 11, :months],
        [12, 23, :months],
        [2, 4, :years],
        [5, 9, :years],
        [10, 14, :years],
        [15, 17, :years],
        [18, 19, :years],
        [20, 24, :years],
        [25, 29, :years],
        [30, 34, :years],
        [35, 39, :years],
        [40, 44, :years],
        [45, 49, :years],
        [50, 120, :years]
      ].freeze

      def regimen_counts
        AGE_GROUPS.map do |start_age, end_age, period|
          start_birthdate = Date.today - end_age.send(period)
          end_birthdate = Date.today - start_age.send(period)

          {
            age_group: "#{start_age} to #{end_age} #{period}",
            male: regimen_counts_by_age_and_gender(start_birthdate, end_birthdate, 'm'),
            female: regimen_counts_by_age_and_gender(start_birthdate, end_birthdate, 'f')
          }
        end
      end

      def regimen_counts_by_age_and_gender(start_birthdate, end_birthdate, gender)
        date = ActiveRecord::Base.connection.quote(end_date)

        Person.select("patient_current_regimen(person_id, #{date}) as regimen, count(*) AS count")
              .where(person_id: patients_that_were_on_treatment,
                     birthdate: (start_birthdate..end_birthdate))
              .where('gender LIKE ?', "#{gender}%")
              .reject { |count| count.count.zero? }
              .collect { |count| { regimen: count.regimen, count: count.count } }
      end

      # Returns all patients that received ART within [start_date, end_date]
      def patients_that_were_on_treatment
        on_arvs = PatientState.where('start_date <= ? AND end_date >= ? AND state = ?',
                                     start_date, end_date, Constants::States::ON_ANTIRETROVIRALS)
                              .group(:patient_program_id)

        PatientProgram.select(:patient_id)
                      .joins(:patient_states)
                      .merge(on_arvs)
                      .where(program_id: Constants::PROGRAM_ID)
      end
    end
  end
end
