# frozen_string_literal: true

module OpdService
  module Reports
    class Attendance
      def find_report(start_date:, end_date:, **_extra_kwargs)
        attendance(start_date, end_date)
      end

      def attendance(start_date, end_date)
        programID = Program.find_by_name 'OPD Program'
        Encounter.find_by_sql(
          "SELECT patient_id, DATE_FORMAT(encounter_datetime,'%Y-%m-%d') enc_date
      FROM encounter e
      WHERE e.voided = 0 AND encounter_datetime BETWEEN '" + start_date.to_date.strftime('%Y-%m-%d 00:00:00') + "'
        AND '" + end_date.to_date.strftime('%Y-%m-%d 23:59:59') + "'
        AND program_id ='" + programID.program_id.to_s + "'
      GROUP BY patient_id,DATE(encounter_datetime)"
        ).map(&:patient_id)
      end
    end
  end
end
