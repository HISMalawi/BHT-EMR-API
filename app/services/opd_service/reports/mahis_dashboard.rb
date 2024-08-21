# frozen_string_literal: true

module OpdService
  module Reports
    # This class is responsible for generating the Mahis Dashboard stats
    class MahisDashboard
      attr_accessor :start_date, :end_date

      def initialize(date: Date.today)
        @start_date = ActiveRecord::Base.connection.quote(date.strftime('%Y-%m-%d 00:00:00'))
        @end_date = ActiveRecord::Base.connection.quote(date.strftime('%Y-%m-%d 23:59:59'))
      end

      def dashboard_stats
        data = daily_data
        {
          total: data.count,
          awaiting_vitals: data.select { |d| d['encounter_type'].casecmp?('REGISTRATION') }.count,
          awaiting_consultation: data.select { |d| d['encounter_type'].casecmp?('VITALS') }.count,
          awaiting_dispensation: data.select { |d| d['encounter_type'].casecmp?('CONSULTATION') }.count
        }
      end

      def all_clients
        data = daily_data
        data.map do |d|
          {
            name: d['patient_name'],
            status: ENCOUNTEMAP[d['encounter_type'].to_sym],
            waiting_time: TimeUtils.smart_time_difference(start_time: d['encounter_datetime'].to_s,
                                                          end_time: Time.now.to_s)
          }
        end
      end

      def awaiting_clients(options = [])
        data = daily_data(options)
        data.map do |d|
          {
            name: d['patient_name'],
            status: ENCOUNTEMAP[d['encounter_type'].to_sym],
            waiting_time: TimeUtils.smart_time_difference(start_time: d['encounter_datetime'].to_s,
                                                          end_time: Time.now.to_s)
          }
        end
      end

      private

      ENCOUNTEMAP = {
        'REGISTRATION': 'Awaiting Vitals',
        'VITALS': 'Awaiting Consultation',
        'CONSULTATION': 'Awaiting Dispensation',
        'TREATMENT': 'Completed Visit'
      }.freeze

      def daily_data(options = [])
        ActiveRecord::Base.connection.select_all <<~SQL
          SELECT p.patient_id, et.name AS encounter_type, COALESCE(e.encounter_datetime, p.date_created) AS encounter_datetime, CONCAT(pe.given_name, ' ', pe.family_name) AS patient_name
          FROM patient p
          INNER JOIN person_name pe ON p.patient_id = pe.person_id AND pe.voided = 0
          INNER JOIN encounter e ON p.patient_id = e.patient_id AND e.voided = 0 AND e.program_id = 14 AND e.encounter_datetime BETWEEN #{@start_date} AND #{@end_date}
          LEFT JOIN encounter ea ON e.patient_id = ea.patient_id AND ea.voided = 0 and ea.program_id = 14 and ea.encounter_datetime > e.encounter_datetime
            AND ea.encounter_datetime BETWEEN #{@start_date} AND #{@end_date}
          LEFT JOIN encounter_type et ON e.encounter_type = et.encounter_type_id AND et.retired = 0
          WHERE p.voided = 0 AND ea.patient_id IS NULL #{options.blank? ? '' : "AND et.name IN (#{options.map { |option| ActiveRecord::Base.connection.quote(option) }.join(',')})"}
        SQL
      end
    end
  end
end
