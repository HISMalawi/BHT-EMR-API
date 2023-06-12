# frozen_string_literal: true

module ARTService
  module Reports
    # This class generates the LIMS results report (results delivered electronically)
    class LimsResults
      attr_reader start_date, end_date

      def initialize(start_date:, end_date:, **_kwargs)
        @start_date = start_date
        @end_date = end_date
      end

      def find_report
        data
      end

      private

      def data
        ActiveRecord::Base.connection.select_all <<~SQL
          SELECT o.start_date AS date_ordered, pn.given_name, pn.family_name, pi.identifier AS arv_number, e.patient_id,
          las.date_received, o.accession_number
          FROM lims_acknowledgement_statuses las
          INNER JOIN orders o ON o.order_id = las.order_id AND o.voided = 0
          INNER JOIN encounter e ON e.encounter_id = o.encounter_id AND e.voided = 0 AND e.program_id = 1 -- HIV PROGRAM
          INNER JOIN users u ON u.user_id = o.orderer
          INNER JOIN person_name pn ON pn.person_id = u.person_id
          LEFT JOIN patient_identifier pi ON pi.patient_id = e.patient_id AND pi.voided = 0 AND pi.identifier_type = #{identifier_type}
          WHERE las.acknowledgement_type = 'test_results_delivered_to_site_electronically'
          AND DATE(las.date_received) BETWEEN '#{start_date}' AND '#{end_date}'
        SQL
      end

      def identifier_type
        filling_number = GlobalPropertyService.use_filing_numbers?

        filling_number ? 17 : 4
      end
    end
  end
end
