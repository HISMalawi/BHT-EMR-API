module TbService::DCTools::RegisteredPatients
  class << self
    include ModelUtils

    def without_program (start_date, end_date)
      registered_patients_query(start_date, end_date).without_program()
    end

    def with_duplicate_tb_number (start_date, end_date)
      tb_number_concept = concept('TB registration number')
      dup_numbers = Observation.select(:value_text)\
                               .where(concept_id: tb_number_concept, obs_datetime: start_date..end_date)\
                               .group(:value_text)\
                               .having('count(*) > 1')
      return nil if dup_numbers.empty?

      Patient.joins(:person => :observations)\
             .where(:obs => { concept_id: tb_number_concept,
                              value_text: dup_numbers.map(&:value_text) })\
             .distinct
    end

    def with_unknown_outcome (start_date, end_date)
      registered_patients_query(start_date, end_date).with_unknown_outcome()
    end

    def with_dispensation_anomalies (start_date, end_date)
      registered_patients_query(start_date, end_date).with_dispensation_anomalies()
    end

    def defaulted (start_date, end_date)
      registered_patients_query(start_date, end_date).defaulted()
    end

    def in_treatment_but_completed (start_date, end_date)
      registered_patients_query(start_date, end_date).in_treatment_but_completed()
    end

    def bad_tb_number (start_date, end_date)
      enrolled_patients_query(start_date, end_date).bad_tb_number()
    end

    def without_tb_number (start_date, end_date)
      enrolled_patients_query(start_date, end_date).without_tb_number()
    end

    private

    def registered_patients_query (start_date, end_date)
      TbQueries::RegisteredPatientsQuery.new.ref(start_date, end_date)
    end

    def enrolled_patients_query (start_date, end_date)
      TbQueries::EnrolledPatientsQuery.new.ref(start_date, end_date)
    end
  end
end