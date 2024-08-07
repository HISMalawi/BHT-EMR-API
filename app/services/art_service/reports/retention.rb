# frozen_string_literal: true

module ArtService
  module Reports
    # Retrieve patients who are completing their first 1st, 3rd, and 6th month on ART
    # in the reporting period.
    class Retention
      attr_reader :start_date, :end_date

      include CommonSqlQueryUtils

      DAYS_IN_MONTH = 28
      MONTHS = [1, 3, 6].freeze

      def initialize(start_date:, end_date:, **kwargs)
        @start_date = start_date.to_s
        @end_date = end_date.to_s
        @use_filing_number = GlobalProperty.find_by(property: 'use.filing.numbers')
                                           &.property_value
                                           &.casecmp?('true')
        @occupation = kwargs[:occupation]
      end

      def find_report
        matched_patients = MONTHS.each_with_object({}) do |month, hash|
          hash[month] = { retained: [], all: [] }
        end

        find_patients_retention_period(retained_patients(as_of: Date.parse(start_date) - MONTHS.max.months)) do |period, patient|
          matched_patients[period][:retained] << {
            patient_id: patient.patient_id,
            arv_number: patient.arv_number,
            start_date: patient.start_date,
            gender: begin
              patient.gender.upcase.first
            rescue StandardError
              nil
            end,
            age_group: patient.age_group,
            end_date: patient.start_date + period.months
          }
        end

        find_patients_retention_period(all_patients(as_of: Date.parse(start_date) - MONTHS.max.months)) do |period, patient|
          matched_patients[period][:all] << {
            patient_id: patient.patient_id,
            arv_number: patient.arv_number,
            gender: begin
              patient.gender.upcase.first
            rescue StandardError
              nil
            end,
            age_group: patient.age_group,
            start_date: patient.start_date
          }
        end

        matched_patients
      end

      def find_patients_retention_period(patients)
        patients.each do |patient|
          retention_period = MONTHS.find do |period|
            (start_date..end_date).include?((patient.start_date + period.months).to_s)
          end

          next unless retention_period

          yield retention_period, patient
        end
      end

      # Pull all patients who started medication before the current reporting period but after
      # the given `as_of` date and have any dispensation that ends in the current reporting
      # period... That's a mouthful woah!!!
      def retained_patients(as_of:)
        start_date = ActiveRecord::Base.connection.quote(self.start_date)
        end_date = ActiveRecord::Base.connection.quote(self.end_date)
        as_of = ActiveRecord::Base.connection.quote(as_of)
        Order.find_by_sql(
          <<~SQL
            SELECT
              initial_orders.patient_id AS patient_id,
              DATE(initial_orders.start_date) AS start_date,
              last_orders.auto_expire_date AS auto_expire_date,
              patient_identifier.identifier AS arv_number,
              disaggregated_age_group(p.birthdate, DATE('#{@end_date}')) age_group,
              p.gender gender
            FROM orders initial_orders
            INNER JOIN encounter initial_encounter ON initial_encounter.encounter_id = initial_orders.encounter_id AND initial_encounter.voided = 0 AND initial_encounter.program_id = 1
            INNER JOIN person p ON p.person_id = initial_orders.patient_id AND p.voided = 0
            LEFT JOIN patient_identifier ON patient_identifier.patient_id = initial_orders.patient_id AND patient_identifier.identifier_type = #{patient_identifier_type_id}
            INNER JOIN (
              SELECT last_order.patient_id, MAX(last_order.auto_expire_date) AS auto_expire_date
                FROM orders last_order
                INNER JOIN encounter last_encounter ON last_encounter.encounter_id = last_order.encounter_id AND last_encounter.voided = 0 AND last_encounter.program_id = 1
                WHERE last_order.auto_expire_date BETWEEN #{start_date} AND #{end_date}
                AND last_order.order_type_id = #{drug_order_type_id}
              AND last_order.voided = 0
                GROUP BY last_order.patient_id
            ) last_orders ON initial_orders.patient_id = last_orders.patient_id
            LEFT JOIN (#{current_occupation_query}) a ON a.person_id = initial_orders.patient_id
            WHERE initial_orders.start_date BETWEEN #{as_of} AND #{start_date}
            AND initial_orders.order_type_id = #{drug_order_type_id} #{%w[Military Civilian].include?(@occupation) ? 'AND' : ''} #{occupation_filter(occupation: @occupation, field_name: 'value', table_name: 'a', include_clause: false)}
            AND initial_orders.auto_expire_date IS NOT NULL
            AND initial_orders.patient_id NOT IN (
              SELECT o.patient_id
              FROM orders o
              INNER JOIN encounter e ON e.encounter_id = o.encounter_id AND e.voided = 0 AND e.program_id = 1
              WHERE o.order_type_id =  #{drug_order_type_id} AND o.start_date < #{as_of} AND o.auto_expire_date IS NOT NULL AND o.voided = 0
            )
            GROUP BY initial_orders.patient_id
        SQL
        )
      end

      def all_patients(as_of:)
        start_date = ActiveRecord::Base.connection.quote(self.start_date)
        as_of = ActiveRecord::Base.connection.quote(as_of)

        Order.find_by_sql(
          <<~SQL
            SELECT initial_order.patient_id AS patient_id,
                   DATE(initial_order.start_date) AS start_date,
                   patient_identifier.identifier AS arv_number,
                   disaggregated_age_group(p.birthdate, DATE('#{@end_date}')) age_group,
                   p.gender gender
            FROM orders initial_order
            INNER JOIN encounter initial_encounter ON initial_encounter.encounter_id = initial_order.encounter_id AND initial_encounter.program_id = 1
            INNER JOIN person p ON p.person_id = initial_encounter.patient_id
            LEFT JOIN patient_identifier ON patient_identifier.patient_id = initial_order.patient_id AND patient_identifier.identifier_type = #{patient_identifier_type_id}
            LEFT JOIN (#{current_occupation_query}) a ON a.person_id = initial_order.patient_id
            WHERE initial_order.start_date BETWEEN #{as_of} AND #{start_date}
              AND initial_order.voided = 0
              AND initial_order.auto_expire_date IS NOT NULL
              AND initial_order.order_type_id = #{drug_order_type_id}
              AND p.voided = 0 #{%w[Military Civilian].include?(@occupation) ? 'AND' : ''} #{occupation_filter(occupation: @occupation, field_name: 'value', table_name: 'a', include_clause: false)}
              AND initial_order.patient_id NOT IN (
                SELECT orders.patient_id
                FROM orders
                  INNER JOIN encounter ON encounter.encounter_id = orders.encounter_id AND encounter.program_id = 1 AND encounter.voided = 0
                WHERE start_date < #{as_of} AND order_type_id = #{drug_order_type_id} AND orders.voided = 0
              )
            GROUP BY initial_order.patient_id
          SQL
        )
      end

      # def retained_patients(as_of:)
      #   start_date = ActiveRecord::Base.connection.quote(self.start_date)
      #   end_date = ActiveRecord::Base.connection.quote(self.end_date)
      #   as_of = ActiveRecord::Base.connection.quote(as_of)

      #   Order.find_by_sql(
      #     <<~SQL
      #       SELECT initial_order.patient_id AS patient_id,
      #              initial_order.start_date AS start_date,
      #              last_order.auto_expire_date AS auto_expire_date,
      #              patient_identifier.identifier AS arv_number,
      #              disaggregated_age_group(p.birthdate, DATE('#{@end_date}')) age_group,
      #              p.gender gender
      #       FROM orders initial_order
      #         INNER JOIN encounter initial_encounter ON initial_encounter.encounter_id = initial_order.encounter_id AND initial_encounter.program_id = 1
      #         INNER JOIN orders last_order ON last_order.patient_id = initial_order.patient_id
      #         INNER JOIN encounter last_encounter ON last_encounter.encounter_id = last_order.encounter_id
      #         INNER JOIN person p ON p.person_id = initial_encounter.patient_id
      #         LEFT JOIN patient_identifier ON patient_identifier.patient_id = initial_order.patient_id
      #       WHERE initial_order.start_date BETWEEN #{as_of} AND #{start_date}
      #         AND initial_order.voided = 0
      #         AND initial_order.auto_expire_date IS NOT NULL
      #         AND initial_order.order_type_id = #{drug_order_type_id}
      #         AND last_order.auto_expire_date BETWEEN #{start_date} AND #{end_date}
      #         AND last_order.order_type_id = #{drug_order_type_id}
      #         AND last_order.voided = 0
      #         AND p.voided = 0
      #         AND initial_order.start_date = (
      #           SELECT MIN(start_date) FROM orders
      #           WHERE patient_id = initial_order.patient_id
      #             AND start_date BETWEEN #{as_of} AND #{start_date}
      #             AND order_type_id = #{drug_order_type_id}
      #             AND voided = 0
      #         )
      #         AND initial_order.patient_id NOT IN (
      #           SELECT orders.patient_id
      #           FROM orders
      #             INNER JOIN encounter ON encounter.encounter_id = orders.encounter_id AND encounter.program_id = 1
      #           WHERE start_date < #{as_of} AND order_type_id = #{drug_order_type_id} AND orders.voided = 0
      #         )
      #       GROUP BY initial_order.patient_id
      #     SQL
      #   )
      # end

      # def all_patients(as_of:)
      #   start_date = ActiveRecord::Base.connection.quote(self.start_date)
      #   as_of = ActiveRecord::Base.connection.quote(as_of)

      #   Order.find_by_sql(
      #     <<~SQL
      #       SELECT initial_order.patient_id AS patient_id,
      #              initial_order.start_date AS start_date,
      #              patient_identifier.identifier AS arv_number,
      #              disaggregated_age_group(p.birthdate, DATE('#{@end_date}')) age_group,
      #              p.gender gender
      #       FROM orders initial_order
      #         INNER JOIN encounter initial_encounter ON initial_encounter.encounter_id = initial_order.encounter_id AND initial_encounter.program_id = 1
      #         INNER JOIN person p ON p.person_id = initial_encounter.patient_id
      #         LEFT JOIN patient_identifier ON patient_identifier.patient_id = initial_order.patient_id AND patient_identifier.identifier_type = #{patient_identifier_type_id}
      #       WHERE initial_order.start_date BETWEEN #{as_of} AND #{start_date}
      #         AND initial_order.voided = 0
      #         AND initial_order.auto_expire_date IS NOT NULL
      #         AND initial_order.order_type_id = #{drug_order_type_id}
      #         AND p.voided = 0
      #         AND initial_order.start_date = (
      #           SELECT MIN(start_date) FROM orders
      #           WHERE patient_id = initial_order.patient_id
      #             AND start_date BETWEEN #{as_of} AND #{start_date}
      #             AND order_type_id = #{drug_order_type_id}
      #             AND voided = 0
      #         )
      #         AND initial_order.patient_id NOT IN (
      #           SELECT orders.patient_id
      #           FROM orders
      #             INNER JOIN encounter ON encounter.encounter_id = orders.encounter_id AND encounter.program_id = 1
      #           WHERE start_date < #{as_of} AND order_type_id = #{drug_order_type_id} AND orders.voided = 0
      #         )
      #       GROUP BY initial_order.patient_id
      #     SQL
      #   )
      # end

      def drug_order_type_id
        @drug_order_type_id ||= OrderType.find_by_name('Drug order').order_type_id
      end

      def patient_identifier_type_id
        return @patient_identifier_type_id if @patient_identifier_type_id

        identifier_type_name = @use_filing_number ? 'Filing Number' : 'ARV Number'
        identifier_type = PatientIdentifierType.find_by_name!(identifier_type_name)

        @patient_identifier_type_id ||= ActiveRecord::Base.connection.quote(identifier_type.id)
      end
    end
  end
end
