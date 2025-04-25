# frozen_string_literal: true

module ArtService
  module Reports
    module Clinic
      # Generates a lab audit trail report for a clinic
      class LabAuditTrailReport
        
        def initialize(start_date:, end_date:, **_kwargs)
          @start_date = ActiveRecord::Base.connection.quote(start_date)
          @end_date = ActiveRecord::Base.connection.quote(end_date)
        end

        def find_report
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT
                orders.accession_number,
                IF(result.present, 'Order and Result', 'Order') lab_encounter,
                DATE(e.date_changed) change_date,
                COALESCE(e.void_reason, 'N/A') reason_for_the_change,
                CONCAT(COALESCE(pn.given_name, ''), ' ', COALESCE(pn.family_name, '')) user,
                IF(e.voided, 'Void', 'Update') AS change_type,
                orders.order_id
            FROM encounter e
            INNER JOIN encounter_type et ON et.encounter_type_id = e.encounter_type
                AND et.name IN ('LAB ORDERS', 'LAB RESULTS')
            INNER JOIN obs o ON o.encounter_id = e.encounter_id
            INNER JOIN users u ON u.user_id = e.changed_by
            INNER JOIN person_name pn ON pn.person_id = u.person_id
            INNER JOIN orders ON orders.encounter_id = e.encounter_id
            LEFT JOIN (
                SELECT e.encounter_id, o.obs_id, o.order_id, res.concept_id present
                FROM obs o
                INNER JOIN encounter e ON e.encounter_id = o.encounter_id
                INNER JOIN obs res ON res.obs_group_id = o.obs_id
                WHERE o.concept_id = #{concept('Lab test result').id}
            ) AS result ON result.order_id = orders.order_id
            WHERE e.date_created != e.date_changed
            AND DATE(e.encounter_datetime) >= #{@start_date}
            AND DATE(e.encounter_datetime) <= #{@end_date}
            GROUP BY orders.accession_number
          SQL
        end
      end
    end
  end
end