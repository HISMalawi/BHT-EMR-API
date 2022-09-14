# frozen_string_literal: true

module ARTService
  module Reports
    module Pepfar
      ## Viral Load Coverage Report
      class ViralLoadCoverage2
        attr_reader :start_date, :end_date

        include Utils

        def initialize(start_date:, end_date:, **_kwargs)
          @start_date = start_date
          @end_date = end_date
        end

        def find_report
          due_for_viral_load
        end

        private

        ## This method prepares the response structure for the report
        def init_report
          pepfar_age_groups.each_with_object({}) do |age_group, report|
            report[age_group] = {
              due_for_vl: [],
              drawn: { routine: [], targeted: [] },
              high_vl: { routine: [], targeted: [] },
              low_vl: { routine: [], targeted: [] }
            }
          end
        end

        def due_for_viral_load
          ActiveRecord::Base.connection.select_all <<~SQL
            #{find_patients_with_overdue_viral_load} UNION #{find_patients_due_for_initial_viral_load}
          SQL
        end

        ##
        # Selects patients whose last viral load should have expired before the end of the reporting period.
        #
        # Patients returned by this aren't necessarily due for viral load, they may have
        # their current milestone delayed. So extra processing on the patients is required
        # to filter out the patients with delayed milestones.
        def find_patients_with_overdue_viral_load
          # Find all patients whose last order's expires in or before the reporting period (making them due)
          # or patients whose first order comes at 6 months or greater after starting ART.
          <<~SQL
            SELECT orders.patient_id,
                   disaggregated_age_group(p.birthdate, DATE(#{ActiveRecord::Base.connection.quote(end_date)})) AS age_group,
                   p.birthdate,
                   p.gender,
                   patient_identifier.identifier AS arv_number
            FROM orders
            INNER JOIN person p ON p.person_id = orders.patient_id
            INNER JOIN order_type
              ON order_type.order_type_id = orders.order_type_id
              AND order_type.name = 'Lab'
              AND order_type.retired = 0
            INNER JOIN concept_name
              ON concept_name.concept_id = orders.concept_id
              AND concept_name.name IN ('Blood', 'DBS (Free drop to DBS card)', 'DBS (Using capillary tube)')
              AND concept_name.voided = 0
            INNER JOIN (
              /* Get the latest order dates for each patient */
              SELECT orders.patient_id, MAX(orders.start_date) AS start_date
              FROM orders
              INNER JOIN order_type
                ON order_type.order_type_id = orders.order_type_id
                AND order_type.name = 'Lab'
                AND order_type.retired = 0
              INNER JOIN concept_name
                ON concept_name.concept_id = orders.concept_id
                AND concept_name.name IN ('Blood', 'DBS (Free drop to DBS card)', 'DBS (Using capillary tube)')
                AND concept_name.voided = 0
              WHERE orders.start_date < DATE(#{ActiveRecord::Base.connection.quote(end_date)}) - INTERVAL 12 MONTH
                AND orders.voided = 0
              GROUP BY orders.patient_id
            ) AS latest_patient_order_date
              ON latest_patient_order_date.patient_id = orders.patient_id
              AND latest_patient_order_date.start_date = orders.start_date
            LEFT JOIN patient_identifier
              ON patient_identifier.patient_id = orders.patient_id
              AND patient_identifier.identifier_type IN (#{pepfar_patient_identifier_type.to_sql})
              AND patient_identifier.voided = 0
            WHERE orders.start_date < DATE(#{ActiveRecord::Base.connection.quote(end_date)}) - INTERVAL 12 MONTH
            GROUP BY orders.patient_id
          SQL
        end

        ##
        # Returns all patients that have been on ART for at least 6 months and have never had a Viral Load.
        def find_patients_due_for_initial_viral_load
          <<~SQL
            SELECT
              p.person_id AS patient_id,
              disaggregated_age_group(p.birthdate, DATE(#{ActiveRecord::Base.connection.quote(end_date)})) age_group,
              p.birthdate,
              p.gender,
              pi.identifier AS arv_number
            FROM person p
            INNER JOIN patient_program pp ON pp.patient_id = p.person_id AND pp.program_id = 1 AND pp.voided = 0
            INNER JOIN patient_state ps ON ps.patient_program_id = pp.patient_program_id AND ps.state = 7
            LEFT JOIN patient_identifier pi ON pi.patient_id = p.person_id AND pi.voided = 0 AND pi.identifier_type IN (#{pepfar_patient_identifier_type.to_sql})
            WHERE p.person_id NOT IN (
              SELECT orders.patient_id
              FROM orders
              INNER JOIN order_type ON order_type.order_type_id = orders.order_type_id AND order_type.name = 'Lab' AND order_type.retired = 0
              INNER JOIN concept_name ON concept_name.concept_id = orders.concept_id AND concept_name.name IN ('Blood', 'DBS (Free drop to DBS card)', 'DBS (Using capillary tube)') AND concept_name.voided = 0
              INNER JOIN obs ON orders.order_id = obs.order_id AND obs.voided = 0
              INNER JOIN concept_name AS cn ON cn.concept_id = obs.concept_id AND cn.name = 'Test type' AND cn.voided = 0
              INNER JOIN concept_name AS test_name ON test_name.concept_id = obs.value_coded AND test_name.name = 'HIV Viral Load' AND test_name.voided = 0
              WHERE orders.start_date <= DATE(#{ActiveRecord::Base.connection.quote(end_date)}) - INTERVAL 12 MONTH
                AND orders.voided = 0
              GROUP BY orders.patient_id
            )
            AND ps.start_date = DATE(#{ActiveRecord::Base.connection.quote(end_date)}) - INTERVAL 6 MONTH
            AND p.voided = 0
            GROUP BY p.person_id
          SQL
        end
      end
    end
  end
end
