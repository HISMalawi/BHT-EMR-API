# frozen_string_literal: true

module ARTService
  module Reports
    class PatientsDueForViralLoad
      attr_accessor :start_date, :end_date

      def initialize(start_date:, end_date:, **_kwargs)
        @start_date = start_date
        @end_date = end_date
      end

      def find_report
        patients_alive_and_on_treatment.select do |patient_id|
          patient_viral_load_due?(patient_id)
        end
      end

      private

      def patient_viral_load_due?(patient_id)
        reminder = viral_load_reminder(patient_id)
        reminder[:eligibile] # Yes its spelt eligibile not eligible...
      end

      def patients_alive_and_on_treatment
        ARTService::Reports::PatientsAliveAndOnTreatment
          .new(start_date: start_date, end_date: end_date)
          .find_report
      end

      def viral_load_reminder(patient_id)
        ARTService::VLReminder
          .new(patient_id: patient_id, date: end_date)
          .vl_reminder_info
      end
    end
  end
end
