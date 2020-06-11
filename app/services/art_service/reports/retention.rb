# frozen_string_literal: true

module ARTService
  module Reports
    class Retention
      attr_reader :start_date, :end_date

      DAYS_IN_MONTH = 28
      MONTHS = [1, 3, 6].freeze

      def initialize(start_date:, end_date:, **_kwargs)
        @start_date = start_date
        @end_date = end_date
      end

      def find_report
        matched_patients = MONTHS.each_with_object({}) { |month, hash| hash[month] = [] }

        patients(as_of: start_date - MONTHS.max.months).each do |patient|
          month = MONTHS.find do |month|
            (start_date..end_date).include?((patient.start_date + month.months).to_date)
          end

          next unless month

          matched_patients[month] << {
            patient_id: patient.patient_id,
            arv_number: patient.arv_number,
            start_date: patient.start_date,
            end_date: patient.start_date + month.months
          }
        end

        matched_patients
      end

      # Pull all patients who started medication before the current reporting period but after
      # the given `as_of` date and have any dispensation that ends in the current reporting
      # period... That's a mouthful woah!!!
      def patients(as_of:)
        start_date = ActiveRecord::Base.connection.quote(self.start_date)
        end_date = ActiveRecord::Base.connection.quote(self.end_date)
        as_of = ActiveRecord::Base.connection.quote(as_of)

        Order.find_by_sql(
          <<~SQL
            SELECT initial_order.patient_id AS patient_id,
                   initial_order.start_date AS start_date,
                   last_order.auto_expire_date AS auto_expire_date,
                   patient_identifier.identifier AS arv_number
            FROM orders initial_order
              INNER JOIN encounter initial_encounter ON initial_encounter.encounter_id = initial_order.encounter_id AND initial_encounter.program_id = 1
              INNER JOIN orders last_order ON last_order.patient_id = initial_order.patient_id
              INNER JOIN encounter last_encounter ON last_encounter.encounter_id = last_order.encounter_id
              LEFT JOIN patient_identifier ON patient_identifier.patient_id = initial_order.patient_id
            WHERE initial_order.start_date BETWEEN #{as_of} AND #{start_date}
              AND initial_order.voided = 0
              AND initial_order.auto_expire_date IS NOT NULL
              AND initial_order.order_type_id = #{drug_order_type_id}
              AND last_order.auto_expire_date BETWEEN #{start_date} AND #{end_date}
              AND last_order.order_type_id = #{drug_order_type_id}
              AND last_order.voided = 0
              AND initial_order.start_date = (
                SELECT MIN(start_date) FROM orders
                WHERE patient_id = initial_order.patient_id
                  AND start_date BETWEEN #{as_of} AND #{start_date}
                  AND order_type_id = #{drug_order_type_id}
                  AND voided = 0
              )
              AND initial_order.patient_id NOT IN (
                SELECT orders.patient_id
                FROM orders
                  INNER JOIN encounter ON encounter.encounter_id = orders.encounter_id AND encounter.program_id = 1
                WHERE start_date < #{as_of} AND order_type_id = #{drug_order_type_id} AND orders.voided = 0
              )
            GROUP BY initial_order.patient_id
          SQL
        )
      end

      def drug_order_type_id
        @drug_order_type_id ||= OrderType.find_by_name('Drug order').order_type_id
      end
    end
  end
end
