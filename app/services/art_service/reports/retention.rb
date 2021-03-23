# frozen_string_literal: true

module ARTService
  module Reports
    # Retrieve patients who are completing their first 1st, 3rd, and 6th month on ART
    # in the reporting period.
    class Retention
      attr_reader :start_date, :end_date

      DAYS_IN_MONTH = 28
      MONTHS = [1, 3, 6].freeze

      def initialize(start_date:, end_date:, **_kwargs)
        @start_date = start_date
        @end_date = end_date
      end

      def find_report
        matched_patients = MONTHS.each_with_object({}) do |month, hash|
          hash[month] = { retained: [], all: [] }
        end

        find_patients_retention_period(retained_patients(as_of: start_date - MONTHS.max.months)) do |period, patient|
          matched_patients[period][:retained] << {
            patient_id: patient.patient_id,
            arv_number: patient.arv_number,
            start_date: patient.start_date,
            gender: (patient.gender.upcase.first rescue nil),
            age_group: patient.age_group,
            end_date: patient.start_date + period.months
          }
        end

        find_patients_retention_period(all_patients(as_of: start_date - MONTHS.max.months)) do |period, patient|
          matched_patients[period][:all] << {
            patient_id: patient.patient_id,
            arv_number: patient.arv_number,
            gender: (patient.gender.upcase.first rescue nil),
            age_group: patient.age_group,
            start_date: patient.start_date
          }
        end

        matched_patients
      end

      def find_patients_retention_period(patients)
        patients.each do |patient|
          retention_period = MONTHS.find do |period|
            (start_date..end_date).include?((patient.start_date + period.months).to_date)
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
            SELECT initial_order.patient_id AS patient_id,
                   initial_order.start_date AS start_date,
                   last_order.auto_expire_date AS auto_expire_date,
                   patient_identifier.identifier AS arv_number,
                   cohort_disaggregated_age_group(p.birthdate, DATE('#{@end_date}')) age_group,
                   p.gender gender
            FROM orders initial_order
              INNER JOIN encounter initial_encounter ON initial_encounter.encounter_id = initial_order.encounter_id AND initial_encounter.program_id = 1
              INNER JOIN orders last_order ON last_order.patient_id = initial_order.patient_id
              INNER JOIN encounter last_encounter ON last_encounter.encounter_id = last_order.encounter_id
              INNER JOIN person p ON p.person_id = initial_encounter.patient_id
              LEFT JOIN patient_identifier ON patient_identifier.patient_id = initial_order.patient_id
            WHERE initial_order.start_date BETWEEN #{as_of} AND #{start_date}
              AND initial_order.voided = 0
              AND initial_order.auto_expire_date IS NOT NULL
              AND initial_order.order_type_id = #{drug_order_type_id}
              AND last_order.auto_expire_date BETWEEN #{start_date} AND #{end_date}
              AND last_order.order_type_id = #{drug_order_type_id}
              AND last_order.voided = 0
              AND p.voided = 0
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

      def all_patients(as_of:)
        start_date = ActiveRecord::Base.connection.quote(self.start_date)
        as_of = ActiveRecord::Base.connection.quote(as_of)

        Order.find_by_sql(
          <<~SQL
            SELECT initial_order.patient_id AS patient_id,
                   initial_order.start_date AS start_date,
                   patient_identifier.identifier AS arv_number,
                   cohort_disaggregated_age_group(p.birthdate, DATE('#{@end_date}')) age_group,
                   p.gender gender
            FROM orders initial_order
              INNER JOIN encounter initial_encounter ON initial_encounter.encounter_id = initial_order.encounter_id AND initial_encounter.program_id = 1
              INNER JOIN person p ON p.person_id = initial_encounter.patient_id
              LEFT JOIN patient_identifier ON patient_identifier.patient_id = initial_order.patient_id
            WHERE initial_order.start_date BETWEEN #{as_of} AND #{start_date}
              AND initial_order.voided = 0
              AND initial_order.auto_expire_date IS NOT NULL
              AND initial_order.order_type_id = #{drug_order_type_id}
              AND p.voided = 0
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
