# frozen_string_literal: true

module TBService
  class DataCleaning
    include ModelUtils

    TOOLS = {
        'WITHOUT PROGRAM' => 'without_program',
        'WITH DUPLICATE TB NUMBER' => 'with_duplicate_tb_number',
        'WITH UNKNOWN OUTCOME' => 'with_unknown_outcome',
        'WITH DISPENSATION ANOMALIES' => 'with_dispensation_anomalies',
        'DEFAULTED' => 'defaulted',
        'IN TREATMENT BUT COMPLETED' => 'in_treatment_but_completed',
        'BAD TB NUMBER' => 'bad_tb_number',
        'WITHOUT TB NUMBER' => 'without_tb_number'
    }.freeze

    def initialize(start_date:, end_date:, scenario:, context:)
      @start_date = start_date.to_date
      @end_date = end_date.to_date
      @scenario = scenario
      @context = context
    end

    def results
        eval(TOOLS[@context.upcase])
    rescue StandardError => e
      "#{e.class}: #{e.message}"
    end

    private

    def without_program
        registered_patients_query.without_program
    end

    def with_duplicate_tb_number
        tb_number_concept = concept('TB registration number')
        dup_numbers = Observation.select(:value_text)\
                                .where(concept_id: tb_number_concept, obs_datetime: @start_date..@end_date)\
                                .group(:value_text)\
                                .having('count(*) > 1')
        return [] if dup_numbers.empty?

        Patient.joins(:person => :observations)\
                .where(:obs => { concept_id: tb_number_concept,
                                value_text: dup_numbers.map(&:value_text) })\
                .distinct
    end

    def with_unknown_outcome
        registered_patients_query.with_unknown_outcome
    end

    def with_dispensation_anomalies
        registered_patients_query.with_dispensation_anomalies
    end

    def defaulted
        registered_patients_query.defaulted
    end

    def in_treatment_but_completed
        registered_patients_query.in_treatment_but_completed
    end

    def bad_tb_number
        enrolled_patients_query.bad_tb_number
    end

    def without_tb_number
        enrolled_patients_query.without_tb_number
    end
    
    def registered_patients_query
        TBQueries::RegisteredPatientsQuery.new.ref(@start_date, @end_date)
    end

    def enrolled_patients_query
        TBQueries::EnrolledPatientsQuery.new.ref(@start_date, @end_date)
    end
  end
end
