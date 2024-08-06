# rubocop:disable Metrics/MethodLength
# frozen_string_literal: true

module CxcaService
  module Reports
    module Clinic
      # Reason for not screening report
      class ReasonForNotScreeningReport
        include Utils
        include ModelUtils

        def initialize(start_date:, end_date:, **_kwargs)
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
          @report = {
            'Hysterectomy' => [],
            'Not due for screening' => [],
            'Preferred counseling' => [],
            'NOT applicable' => [],
            'Patient refused' => [],
            'Chemotherapy' => [],
            'Pregnancy' => [],
            'Services NOT available' => [],
            'Provider NOT available' => []
          }
        end

        def process_report
          (fetch_query || []).each do |row|
            if @report.keys.include?(row['reason_for_not_screening'])
              @report[row['reason_for_not_screening']] << row['patient_id']
            end
            # Hack due to concept name coming from frontend not matching
            @report['Not due for screening'] << row['patient_id'] \
              if row['reason_for_not_screening'] == 'Screened for Cervical Cancer'
          end
        end

        def fetch_query
          cxca_program = Program.find_by_name('CxCa program').id
          art_program = Program.find_by_name('HIV Program').id

          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT
              p.patient_id,
              CASE
                WHEN reason.concept_id = #{concept('Pregnant?').concept_id}#{' '}
                AND reason.value_coded = #{ConceptName.find_by(name: 'Yes').concept_id}
                THEN 'Pregnancy'
                ELSE reason_name.name
              END AS reason_for_not_screening
            FROM patient p
            INNER JOIN encounter ON encounter.patient_id = p.patient_id
            AND encounter.voided = 0
            AND (encounter.program_id = #{cxca_program} OR encounter.program_id = #{art_program})
            AND encounter.encounter_datetime >= '#{@start_date}'
            AND encounter.encounter_datetime <= '#{@end_date}'
            INNER JOIN obs reason ON reason.encounter_id = encounter.encounter_id
            AND reason.voided = 0
            AND (reason.concept_id = #{concept('Reason for NOT offering CxCa').concept_id}#{' '}
                 OR (reason.concept_id = #{concept('Pregnant?').concept_id}#{' '}
                 AND reason.value_coded = #{ConceptName.find_by(name: 'Yes').concept_id}))
            INNER JOIN concept_name reason_name#{' '}
            ON reason_name.concept_id = reason.value_coded
            AND reason_name.voided = 0
            WHERE p.voided = 0
            GROUP BY p.patient_id, reason_for_not_screening
          SQL
        end
      end
    end
  end
end

# rubocop:enable Metrics/MethodLength
