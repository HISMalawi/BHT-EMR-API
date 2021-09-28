# frozen_string_literal: true

module ARTService
  module Reports
    # Returns all patients alive and on treatment within a given
    # time period (Tx Curr).
    class PatientsAliveAndOnTreatment
      attr_reader :start_date, :end_date

      include ConcurrencyUtils

      def initialize(start_date:, end_date:, rebuild_outcomes: true, **_kwargs)
        @start_date = start_date
        @end_date = end_date
        @rebuild_outcomes = rebuild_outcomes
      end

      ##
      # Repopulates temp_patient_outcomes and temp_earliest_start_date tables.
      #
      # The data in temp_patient_outcomes can be used to quickly find patients
      # with various outcomes.
      def refresh_outcomes_table
        logger.debug('Initialising cohort temporary tables...')
        CohortBuilder.new.init_temporary_tables(@start_date, @end_date)
      end

      def find_report
        query.map(&:patient_id)
      end

      def query
        with_lock('art_service/reports/tx_curr.lock') do
          refresh_outcomes_table if @rebuild_outcomes || !outcomes_table_exists?

          Patient.find_by_sql <<~SQL
            SELECT patient_id FROM temp_patient_outcomes WHERE cum_outcome LIKE 'On antiretrovirals'
          SQL
        end
      end

      private

      def outcomes_table_exists?
        ActiveRecord::Base.connection.table_exists?(:temp_patient_outcomes)
      end

      def logger
        Rails.logger
      end
    end
  end
end
