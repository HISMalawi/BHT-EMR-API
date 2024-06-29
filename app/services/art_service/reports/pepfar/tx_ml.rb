# frozen_string_literal: true

module ArtService
  module Reports
    module Pepfar
      class TxMl
        attr_reader :start_date, :end_date, :rebuild, :occupation

        include Utils
        include CommonSqlQueryUtils

        def initialize(start_date:, end_date:, **kwargs)
          @start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
          @end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')
          @occupation = kwargs[:occupation]
          @rebuild = kwargs[:rebuild]&.casecmp?('true')
        end

        def data
          if rebuild
            ArtService::Reports::CohortBuilder.new(outcomes_definition: 'pepfar').init_temporary_tables(start_date,
                                                                                                        end_date, occupation)
          end
          process_data
        end

        private

        def process_data
          data = {}
          (process_tx_ml_clients || []).each do |pat|
            patient_id = pat['patient_id'].to_i
            outcome = pat['outcome']
            gender = begin
              pat['gender'].first.upcase
            rescue StandardError
              'Unknown'
            end
            age_group = pat['age_group']

            if data[age_group].blank?
              data[age_group] = {}
              data[age_group][gender] = [[], [], [], [], [], []]
            elsif data[age_group][gender].blank?
              data[age_group][gender] = [[], [], [], [], [], []]
            end

            case outcome
            when 'Defaulted'
              def_months = pat['months'].to_i
              if def_months < 3
                data[age_group][gender][1] << patient_id
              elsif def_months <= 5
                data[age_group][gender][2] << patient_id
              elsif def_months > 5
                data[age_group][gender][3] << patient_id
              end
            when 'Patient died'
              data[age_group][gender][0] << patient_id
            when /Stopped/i
              data[age_group][gender][5] << patient_id
            when 'Patient transferred out'
              data[age_group][gender][4] << patient_id
            end
          rescue StandardError => e
            Rails.logger.error(e.message)
          end
          data
        end

        def tx_ml_clients
          <<~SQL
            SELECT
              e.patient_id,
              e.birthdate,
              e.gender,
              e.date_enrolled,
              e.earliest_start_date,
              o.outcome_date,
              TIMESTAMPDIFF(MONTH, DATE(e.earliest_start_date), DATE(o.outcome_date)) months,
              disaggregated_age_group(e.birthdate, DATE('#{end_date}')) age_group,
              o.cum_outcome outcome
            FROM temp_earliest_start_date e
            INNER JOIN temp_patient_outcomes o ON e.patient_id = o.patient_id AND o.cum_outcome IN ('Defaulted', 'Patient died', 'Treatment stopped', 'Patient transferred out')
            LEFT JOIN (#{current_occupation_query}) a ON a.person_id = e.patient_id
            WHERE e.patient_id IN (SELECT patient_id FROM temp_patient_outcomes_start WHERE cum_outcome = 'On antiretrovirals')
            AND DATE(e.earliest_start_date) < '#{start_date.to_date}'
            GROUP BY e.patient_id
          SQL
        end

        def tx_ml_clients_new
          <<~SQL
            SELECT
              e.patient_id,
              e.birthdate,
              e.gender,
              e.date_enrolled,
              e.earliest_start_date,
              o.outcome_date,
              TIMESTAMPDIFF(MONTH, DATE(e.earliest_start_date), DATE(o.outcome_date)) months,
              disaggregated_age_group(e.birthdate, DATE('#{end_date}')) age_group,
              o.cum_outcome outcome
            FROM temp_earliest_start_date e
            INNER JOIN temp_patient_outcomes o ON e.patient_id = o.patient_id AND o.cum_outcome IN ('Defaulted', 'Patient died', 'Treatment stopped', 'Patient transferred out')
            LEFT JOIN (#{current_occupation_query}) a ON a.person_id = e.patient_id
            WHERE e.earliest_start_date BETWEEN DATE('#{start_date}') AND DATE('#{end_date}')
            GROUP BY e.patient_id
          SQL
        end

        def process_tx_ml_clients
          ActiveRecord::Base.connection.select_all <<~SQL
            (#{tx_ml_clients})
            UNION
            (#{tx_ml_clients_new})
          SQL
        end
      end
    end
  end
end
