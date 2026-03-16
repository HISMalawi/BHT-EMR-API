# app/services/patient_record_service/patient_enrollment_manager.rb
# frozen_string_literal: true

module PatientRecordService
  class PatientEnrollmentManager < BaseSaver
    def enroll_program(patient_id, record)
      enrollment = record[:activePrograms]
      return false if enrollment.blank?

      enrollments = enrollment.is_a?(Array) ? enrollment : [enrollment]

      unsaved_enrollments = enrollments.select do |item|
        item.present? && item[:status] == "unsaved"
      end

      return false if unsaved_enrollments.empty?

      begin
        ActiveRecord::Base.transaction do
          unsaved_enrollments.each do |enroll|
            next unless enroll

            if PatientProgram.where(program_id: enroll[:program_id], patient_id: patient_id).exists?
              Rails.logger.info("Patient #{patient_id} already enrolled in program #{enroll[:program_id]}, skipping")
              next
            end

            PatientProgram.create!(
              program_id: enroll[:program_id],
              date_enrolled: enroll[:date_enrolled] || Time.now,
              location_id: enroll[:location_id] ,
              patient_id: patient_id
            )

            Rails.logger.info('Successfully created patient program')
          end
        end

        true
      rescue StandardError => e
        log_error("Failed to create patient enrollment", e)
        raise
      end
    end
  end
end