# frozen_string_literal: true

module ARTService
  module Reports
    class RegimensByWeightAndGender
      attr_reader :start_date, :end_date

      def initialize(start_date:, end_date:, **_kwargs)
        @start_date = start_date
        @end_date = end_date
        @rebuild_outcomes = true
      end

      def find_report
        regimen_counts
      end

      private

      WEIGHT_BANDS = [
        [3, 3.9],
        [4, 4.9],
        [6, 9.9],
        [10, 13.9],
        [14, 19.9],
        [20, 24.9],
        [25, 29.9],
        [30, 34.9],
        [35, 39.9],
        [40, Float::INFINITY],
        [nil, nil] # To capture all those missing weight
      ].freeze

      def regimen_counts
        PatientsAliveAndOnTreatment.new(start_date: start_date, end_date: end_date)
                                   .refresh_outcomes_table

        WEIGHT_BANDS.map do |start_weight, end_weight|
          {
            weight: weight_band_to_string(start_weight, end_weight),
            males: regimen_counts_by_weight_and_gender(start_weight, end_weight, 'M'),
            females: regimen_counts_by_weight_and_gender(start_weight, end_weight, 'F'),
            unknown_gender: regimen_counts_by_weight_and_gender(start_weight, end_weight, nil)
          }
        end
      end

      def weight_band_to_string(start_weight, end_weight)
        if start_weight.nil? && end_weight.nil?
          'Unknown'
        elsif end_weight == Float::INFINITY
          "#{start_weight} Kg +"
        else
          "#{start_weight} - #{end_weight} Kg"
        end
      end

      # TODO: Refactor the queries in this module... Possibly
      # prefer joins over the subqueries (ie if performance becomes an
      # issue - it probably will eventually).

      def regimen_counts_by_weight_and_gender(start_weight, end_weight, gender)
        date = ActiveRecord::Base.connection.quote(end_date)

        query = TempPatientOutcome.joins('INNER JOIN temp_earliest_start_date USING (patient_id)')
                                  .select("patient_current_regimen(patient_id, #{date}) as regimen, count(*) AS count")
                                  .where(patient_id: patients_in_weight_band(start_weight, end_weight))
                                  .where(patient_id: patients_with_arv_dispensations)
                                  .where(cum_outcome: 'On Antiretrovirals')
                                  .group(:regimen)

        query = gender ? query.where('gender LIKE ?', "#{gender}%") : query.where('gender IS NULL')

        query.collect { |obs| { obs.regimen => obs.count } }
      end

      def patients_in_weight_band(start_weight, end_weight)
        if start_weight.nil? && end_weight.nil?
          # If no weight is provided then this must be all patients without a weight observation
          return PatientProgram.select(:patient_id)
                               .where(program_id: ARTService::Constants::PROGRAM_ID)
                               .where.not(patient_id: patients_with_known_weight)
        end

        patients_with_known_weight.where(value_numeric: (start_weight..end_weight))
      end

      def patients_with_known_weight
        Observation.select('DISTINCT obs.person_id')
                   .joins('INNER JOIN temp_patient_outcomes AS outcomes ON outcomes.patient_id = obs.person_id')
                   .where(concept_id: ConceptName.where(name: 'Weight (kg)').select(:concept_id),
                          outcomes: { cum_outcome: 'On antiretrovirals' })
                   .where('obs.obs_datetime < ?', end_date)
      end

      def patients_with_arv_dispensations
        Order.joins('INNER JOIN temp_patient_outcomes AS outcomes ON outcomes.patient_id = orders.patient_id')
             .where(concept: ConceptSet.find_members_by_name('Antiretroviral drugs').select(:concept_id))
             .where('start_date >= DATE(?) AND start_date < DATE(?) + INTERVAL 1 DAY', start_date, end_date)
             .where(outcomes: { cum_outcome: 'On antiretrovirals' })
             .select(:patient_id)
      end
    end
  end
end
