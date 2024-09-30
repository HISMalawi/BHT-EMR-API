# frozen_string_literal: true

module TbService
  module Reports
    module MdrInterimOutcomes
      class << self
        AGE_GROUPS = {
          '0-4' => [0, 4],
          '5-14' => [5, 14],
          '15-24' => [15, 24],
          '25-34' => [25, 34],
          '35-44' => [35, 44],
          '45-54' => [45, 54],
          '55-64' => [55, 64],
          '65+' => [65, 200]
        }.freeze

        def report_format(indicator)
          format_ = {
            indicator:
          }
          AGE_GROUPS.each_key do |k|
            format_[k] = {
              male: [],
              female: []
            }
          end
          format_
        end

        def format_report(indicator:, report_data:, **_kwargs)
          data = report_format(indicator)
          report_data
            &.each do |patient|
            process_patient(patient, data)
          end
          data
        end

        def process_patient(patient, data)
          age = patient.age
          gender = patient.gender == 'M' ? :male : :female
          age_group = AGE_GROUPS.keys.find { |k| age.between?(*AGE_GROUPS[k]) }
          data[age_group][gender] << patient.id
        end

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
          TbService::TbQueries::MdrOutcomeQuery.new
        end

        def mdr_patient_query
          TbService::TbQueries::MdrPatientQuery.new
        end

        def mdr_examination_query
          TbService::TbQueries::MdrQuery.new
        end
      end
    end
  end
end
