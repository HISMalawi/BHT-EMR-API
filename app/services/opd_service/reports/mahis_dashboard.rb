# frozen_string_literal: true

module OpdService
  module Reports
    # This class is responsible for generating the Mahis Dashboard stats
    class MahisDashboard
      attr_accessor :start_date, :end_date

      def initialize
        @start_date = ActiveRecord::Base.connection.quote(Date.today.strftime('%Y-%m-%d 00:00:00'))
        @end_date = ActiveRecord::Base.connection.quote(Date.today.strftime('%Y-%m-%d 23:59:59'))
      end

      def dashboard_stats
        data = ActiveRecord::Base.connection.select_all <<~SQL
          SELECT
            p.patient_id,
            et.name AS encounter_type,
            TIMESTAMPDIFF(MINUTE, NOW(), COALESCE(e.encounter_datetime, p.date_created)) AS waiting_time
          FROM patient p
          LEFT JOIN encounter e ON p.patient_id = e.patient_id AND e.voided = 0 AND e.program_id = 14 AND e.encounter_datetime BETWEEN #{@start_date} AND #{@end_date}
          LEFT JOIN encounter ea ON e.patient_id = ea.patient_id AND ea.voided = 0 and ea.program_id = 14 and ea.encounter_datetime > e.encounter_datetime
            AND ea.encounter_datetime BETWEEN #{@start_date} AND #{@end_date}
          LEFT JOIN encounter_type et ON e.encounter_type = et.encounter_type_id AND et.retired = 0
          WHERE p.voided = 0 AND ea.patient_id IS NULL AND (e.encounter_datetime IS NULL OR p.date_created BETWEEN #{@start_date} AND #{@end_date})
        SQL
        {
          total: data.count,
          awaiting_vitals: data.select { |d| d['encounter_type'].casecmp?('REGISTRATION') }.count,
          awaiting_consultation: data.select { |d| d['encounter_type'].casecmp?('VITALS') }.count,
          awaiting_dispensation: data.select { |d| d['encounter_type'].casecmp?('CONSULTATION') }.count
        }
      end
    end
  end
end
