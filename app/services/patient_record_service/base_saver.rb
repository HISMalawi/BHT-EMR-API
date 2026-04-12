# app/services/patient_record_service/base_saver.rb
# frozen_string_literal: true

module PatientRecordService
  class BaseSaver
    include EncounterCreation # Include shared encounter logic

    def errors
      @errors ||= []
    end

    def clear_errors!
      @errors = []
    end

    private

    def person_service
      @person_service ||= PersonService.new
    end

    def log_error(message, error)
      full_message = "#{message}: #{error.message}"
      errors << full_message

      Rails.logger.error(full_message)
      Rails.logger.error(error.backtrace.join("\n")) if error.backtrace
    end
  end
end
