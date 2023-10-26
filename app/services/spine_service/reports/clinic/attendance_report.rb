# frozen_string_literal: true

module SpineService
  module Reports
    module Clinic
      class AttendanceReport
        include ModelUtils
        attr_reader :start_date, :end_date

        def initialize(start_date:, end_date:, **kwargs)
          @start_date = start_date.to_date.beginning_of_day.strftime('%Y-%m-%d %H:%M:%S')
          @end_date = end_date.to_date.end_of_day.strftime('%Y-%m-%d %H:%M:%S')
        end

        def fetch_report
          data = Encounter.where(
              'encounter_datetime BETWEEN ? AND ? AND program_id = ? AND voided = 0', 
              @start_date, 
              @end_date, 
              program("Spine Program").program_id.to_s
            )
            .group('patient_id, DATE(encounter_datetime)')
            .select("patient_id, DATE_FORMAT(encounter_datetime,'%Y-%m-%d') enc_date")
          
          results = (data || []).map{|e| e.patient_id}
          results
        end
      end
    end
  end
end