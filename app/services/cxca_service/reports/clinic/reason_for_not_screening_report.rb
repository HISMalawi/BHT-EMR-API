# frozen_string_literal: true

module CXCAService
  module Reports
    module Clinic
      # Reason for not screening report
      class ReasonForNotScreeningReport
        include Utils
        include ModelUtils


        REASONS_FOR_DENIAL = {
          "Hysterectomy" => [],
          "Not due for screening" => [],
          "Client preferred counseling" => [],
          "Not applicable" => [],
          "Patient refused" => [],
          "Chemotherapy" => [],
          "Services not available" => [],
          "Provider not available"  => []
        }
        

        def initialize(start_date:, end_date:)
          @start_date = start_date.to_date.beginning_of_day.strftime('%Y-%m-%d %H:%M:%S')
          @end_date = end_date.to_date.end_of_day.strftime('%Y-%m-%d %H:%M:%S')
        end

        def data
          init_report
          process_report
          @report
        rescue StandardError => e
          Rails.logger.error e.message
          Rails.logger.error e.backtrace.join("\n")
          raise e
        end

        private

        def init_report
          @report = REASONS_FOR_DENIAL
        end

        def process_report
          (fetch_query || []).each do |row|
            @report[row['reason_for_not_screening']] << row['patient_id'] if @report.keys.include?(row['reason_for_not_screening'])
          end
        end

        def fetch_query
          cxca_program = Program.find_by_name('CxCa program').id

          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT
              p.patient_id,
              reason_name.name reason_for_not_screening
            FROM patient p
            INNER JOIN encounter on encounter.patient_id = p.patient_id
            LEFT JOIN obs reason_for_not_screening ON reason_for_not_screening.person_id = encounter.patient_id
                AND reason_for_not_screening.voided = 0
                AND reason_for_not_screening.concept_id = #{concept('Reason for NOT offering CxCa').concept_id}
            LEFT JOIN concept_name reason_name ON reason_name.concept_id = reason_for_not_screening.value_coded
                AND reason_name.voided = 0
            WHERE p.voided = 0
            AND encounter.voided = 0
            AND encounter.program_id = (#{cxca_program})
            AND encounter.encounter_datetime >= '#{@start_date}'
            AND encounter.encounter_datetime <= '#{@end_date}'
            GROUP BY p.patient_id
          SQL
        end
      end
    end
  end
end
