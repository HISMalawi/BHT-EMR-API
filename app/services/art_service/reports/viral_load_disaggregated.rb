# frozen_string_literal: true

module ARTService
  module Reports
    class ViralLoadDisaggregated
      attr_reader :start_date, :end_date, :from, :to

      def initialize(start_date:, end_date:, from: nil, to: nil, **_kwargs)
        @start_date = start_date.to_date
        @end_date = end_date.to_date
        @from = from&.to_f
        @to = to&.to_f
      end

      def find_report
        patients.each_with_object({}) do |patient, report|
          age_group = find_age_group(patient.birthdate)
          regimen = patient.regimen&.upcase
          report[age_group] ||= {}

          if report[age_group].include?(regimen)
            report[age_group][regimen] += 1
          else
            report[age_group][regimen] = 1
          end
        end
      end

      private

      AGE_GROUPS = [
        [1, 4],
        [5, 9],
        [10, 14],
        [15, 19],
        [20, 24],
        [25, 29],
        [30, 34],
        [35, 39],
        [40, 44],
        [45, 49],
        [50, 54],
        [55, 59],
        [60, 64],
        [65, 69],
        [70, 74],
        [75, 79],
        [80, 84],
        [85, 89],
        [90, Float::INFINITY]
      ].freeze

      # Returns all patients with a viral load in the selected range
      # and the regimens they are on the given point in time.
      def patients
        Observation.select('patient_id, birthdate, patient_current_regimen(patient_id, obs_datetime) as regimen')
                   .joins(:encounter)
                   .joins('INNER JOIN person USING (person_id)')
                   .where(concept_id: ConceptName.find_by_name('Viral load').concept_id,
                          obs_datetime: (start_date..end_date),
                          value_numeric: viral_load_range)
                   .merge(Encounter.where(encounter_type: EncounterType.find_by_name('LAB ORDERS').encounter_type_id))
                   .group(:person_id)
                   .order(obs_datetime: :desc)
      end

      DAYS_IN_YEAR = 365

      def find_age_group(birthdate)
        return 'Unknown' unless birthdate

        age = (end_date.to_date - birthdate.to_date).to_i / DAYS_IN_YEAR
        return '<1 year' if age < 1

        start_age, end_age = AGE_GROUPS.find { |start_age, end_age| (start_age..end_age).include?(age) }

        if end_age == Float::INFINITY
          "#{start_age} years +"
        else
          "#{start_age} - #{end_age} years"
        end
      end

      def viral_load_range
        if from && to
          from..to
        elsif from
          from..Float::INFINITY
        elsif to
          0..to
        else
          0...1
        end
      end
    end
  end
end
