# frozen_string_literal: true

module ARTService
  module Reports
    Constants = ARTService::Constants

    class RegimensByWeightAndGender
      attr_reader :start_date, :end_date

      def initialize(start_date:, end_date:, **_kwargs)
        @start_date = start_date
        @end_date = end_date
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

        query = Person.select("patient_current_regimen(person_id, #{date}) as regimen, count(*) AS count")
                      .where(person_id: patients_alive_and_on_art)
                      .where(person_id: patients_in_weight_band(start_weight, end_weight))
                      .where(person_id: patients_with_arv_dispensations)
                      .group(:regimen)

        query = gender ? query.where('gender LIKE ?', "#{gender}%") : query.where(gender: nil)

        query.collect { |obs| { obs.regimen => obs.count } }
      end

      def patients_in_weight_band(start_weight, end_weight)
        if start_weight.nil? && end_weight.nil?
          # If no weight is provided then this must be all patients without a weight observation
          return PatientProgram.select(:patient_id)
                               .where(program_id: Constants::PROGRAM_ID)
                               .where.not(patient_id: patients_with_known_weight)
        end

        patients_with_known_weight.where(value_numeric: (start_weight..end_weight))
      end

      def patients_with_known_weight
        Observation.select('DISTINCT obs.person_id')
                   .where(concept_id: ConceptName.where(name: 'Weight (kg)').select(:concept_id))
                   .where('obs.obs_datetime < ?', end_date)
      end

      def patients_with_arv_dispensations
        Order.joins(:drug_order)
             .merge(DrugOrder.where(drug_inventory_id: Drug.arv_drugs))
             .where('start_date >= :start_date OR (start_date <= :end_date AND auto_expire_date >= :start_date)',
                    start_date: start_date, end_date: end_date)
             .select(:patient_id)
      end

      def patients_alive_and_on_art
        PatientsAliveAndOnTreatment.new(start_date: end_date, end_date: end_date)
                                   .query
      end
    end
  end
end
