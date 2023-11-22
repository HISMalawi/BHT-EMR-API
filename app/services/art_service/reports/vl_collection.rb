# frozen_string_literal: true

module ArtService
  module Reports
    # Report for Showing all HIV Viral Load Tests Done Or Sample Collected per the specified period
    class VlCollection
      include CommonSqlQueryUtils
      def initialize(start_date:, end_date:, **kwargs)
        @start_date = start_date.to_date.beginning_of_day
        @end_date = end_date.to_date.end_of_day
        @occupation = kwargs[:occupation]
      end

      def find_report
        data
      end

      private

      def data
        ActiveRecord::Base.connection.select_all <<~SQL
          SELECT
            o.person_id AS patient_id,
            pn.given_name,
            pn.family_name,
            p.gender,
            p.birthdate,
            i.identifier AS identifier,
            DATE(ord.start_date) AS order_date
          FROM obs o
          INNER JOIN orders ord ON ord.order_id = o.order_id AND ord.voided = 0
          INNER JOIN person p ON p.person_id = o.person_id AND p.voided = 0
          INNER JOIN person_name pn ON pn.person_id = p.person_id AND pn.voided = 0
          LEFT JOIN patient_identifier i ON i.patient_id = p.person_id AND i.voided = 0 AND i.identifier_type = #{indetifier_type}
          LEFT JOIN (#{current_occupation_query}) AS a ON a.person_id = p.person_id
          WHERE o.concept_id = 9737 -- Test Type
          AND o.value_coded = 856 -- Viral Load
          AND o.obs_datetime BETWEEN '#{@start_date}' AND '#{@end_date}'
          AND o.voided = 0 #{%w[Military Civilian].include?(@occupation) ? 'AND' : ''} #{occupation_filter(occupation: @occupation, field_name: 'value', table_name: 'a', include_clause: false)}
        SQL
      end

      def indetifier_type
        @indetifier_type ||= PatientIdentifierType.find_by_name!(GlobalPropertyService.use_filing_numbers? ? 'Filing Number' : 'ARV Number').id
      end
    end
  end
end
