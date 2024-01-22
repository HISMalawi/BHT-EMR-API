# frozen_string_literal: true
module TBService::Reports::MdrInterimOutcomes
  class << self

    def culture_negative(start_date, end_date)
      query = mdr_patient_query.ref(start_date, end_date).tb_status('Negative')
      patients = query.present? ? query.map(&:patient_id) : []

      mdr_examination_query.culture_done(start_date, end_date)\
                           .where(patient_id: patients)\
                           .distinct
    end

    def culture_positive(start_date, end_date)
      query = mdr_patient_query.ref(start_date, end_date).tb_status('Positive')
      patients = query.present? ? query.map(&:patient_id) : []

      mdr_examination_query.culture_done(start_date, end_date)\
                           .where(patient_id: patients)\
                           .distinct
    end

    def culture_and_smear_not_done(start_date, end_date)
        query = mdr_patient_query.ref(start_date, end_date)
        patients = query.present? ? query.map(&:patient_id) : []

        mdr_examination_query.culture_not_done(start_date, end_date)\
                             .where(patient_id: patients)\
                             .distinct
    end

    def transfer_out(start_date, end_date)
      to_result('Patient transferred out', start_date, end_date)
    end

    def died(start_date, end_date)
      to_result('Patient died', start_date, end_date)
    end

    def lost_to_follow_up(start_date, end_date)
      to_result('Lost to follow up', start_date, end_date)
    end

    private

    def to_result(outcome, start_date, end_date)
      query = patient_outcome_query.ref(start_date, end_date).distinct
      patients = query.present? ? query.map(&:patient_id) : []
      patient_outcome_query.outcome(outcome, patients, start_date, end_date)
    end

    def patient_outcome_query
      TBQueries::MdrOutcomeQuery.new
    end

    def mdr_patient_query
      TBQueries::MdrPatientQuery.new
    end

    def mdr_examination_query
      TBQueries::MdrQuery.new
    end

  end
end
