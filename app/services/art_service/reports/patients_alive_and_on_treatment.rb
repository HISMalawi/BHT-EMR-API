# frozen_string_literal: true

module ARTService
  module Reports
    # Returns all patients alive and on treatment within a given
    # time period (Tx Curr).
    class PatientsAliveAndOnTreatment
      attr_accessor :start_date, :end_date

      def initialize(start_date:, end_date:, rebuild_outcomes: true, **_kwargs)
        @start_date = start_date
        @end_date = end_date

        initialize_temporary_tables if rebuild_outcomes || !outcomes_table_exists?
      end

      def find_report
        query.map(&:patient_id)
      end

      def query
        Patient.find_by_sql <<~SQL
          SELECT patient_id FROM temp_patient_outcomes WHERE cum_outcome LIKE 'On antiretrovirals'
        SQL
      end

      private

      def initialize_temporary_tables
        logger.debug('Initialising cohort temporary tables...')
        CohortBuilder.new.init_temporary_tables(start_date, end_date)
      end

      def outcomes_table_exists?
        ActiveRecord::Base.connection.table_exists?(:temp_patient_outcomes)
      end

      def logger
        Rails.logger
      end
    end
  end
end
