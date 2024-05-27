# frozen_string_literal: true

module ArtService
  module Reports
    # This class generates the LIMS results report (results delivered electronically)
    class LimsResults
      include CommonSqlQueryUtils
      attr_reader :start_date, :end_date

      def initialize(start_date:, end_date:, **kwargs)
        @start_date = start_date
        @end_date = end_date
        @occupation = kwargs[:occupation]
      end

      def find_report
        data
      end

      private

      def data
        ActiveRecord::Base.connection.select_all <<~SQL
          SELECT o.start_date AS date_ordered, pn.given_name, pn.family_name, pi.identifier AS arv_number, e.patient_id,
          las.date_received, o.accession_number, CONCAT(COALESCE(res.value_modifier, '='), COALESCE(res.value_text, res.value_numeric)) AS result,
          cn.name AS test_name, las.acknowledgement_type AS result_delivery_mode, statuses.value_text AS order_status, reason_test.name AS test_reason
          FROM orders o
          LEFT JOIN lims_acknowledgement_statuses las ON las.order_id = o.order_id
          INNER JOIN encounter e ON e.encounter_id = o.encounter_id AND e.voided = 0 AND (e.program_id = 1 OR e.program_id = 23) -- HIV PROGRAM AND Laboratory program
          INNER JOIN users u ON u.user_id = o.orderer
          INNER JOIN person_name pn ON pn.person_id = u.person_id
          INNER JOIN obs test ON test.person_id = e.patient_id AND test.voided = 0 AND test.order_id = o.order_id AND test.concept_id = 9737 -- 'Test Type'
          INNER JOIN concept_name cn ON cn.concept_id = test.value_coded AND cn.voided = 0 AND cn.locale_preferred = 1
          LEFT JOIN patient_identifier pi ON pi.patient_id = e.patient_id AND pi.voided = 0 AND pi.identifier_type = #{identifier_type}
          LEFT JOIN obs ON obs.person_id = e.patient_id AND obs.voided = 0 AND obs.order_id = o.order_id
            AND obs.concept_id = 7363 -- 'Lab test result'
          LEFT JOIN obs statuses ON statuses.order_id = o.order_id AND statuses.voided = 0 AND statuses.concept_id = 10682 -- 'lab order status'
          LEFT JOIN obs res ON res.obs_group_id = obs.obs_id AND res.voided = 0 AND res.order_id = o.order_id
          LEFT JOIN obs reason ON reason.order_id = o.order_id AND reason.voided = 0  AND reason.concept_id = 2429 -- 'Reason for test'
          LEFT JOIN concept_name reason_test ON reason_test.concept_id = reason.value_coded AND reason_test.voided = 0
          LEFT JOIN (#{current_occupation_query}) AS a ON a.person_id = e.patient_id
          WHERE DATE(o.start_date) BETWEEN '#{start_date}' AND '#{end_date}' AND o.voided = 0 #{%w[Military Civilian].include?(@occupation) ? 'AND' : ''} #{occupation_filter(occupation: @occupation, field_name: 'value', table_name: 'a', include_clause: false)}
          AND cn.name ="HIV viral load" GROUP BY o.order_id
        SQL
      end

      def identifier_type
        filling_number = GlobalPropertyService.use_filing_numbers?

        filling_number ? 17 : 4
      end
    end
  end
end
