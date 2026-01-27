# app/services/patient_record_service/dispensation_saver.rb
# frozen_string_literal: true

module PatientRecordService
  class DispensationSaver < BaseSaver
    def save_dispensation_data(patient_id, record)
      begin
        unsaved_data = record.dig(:dispensations, :unsaved)
        return false unless unsaved_data&.any?

        permitted_data = unsaved_data.map do |dispensation_params|
          dispensation_params.permit(
            :provider_id,
            :program_id,
            :patient_id,
            dispensations: [:drug_order_id, :date, :quantity]
          )
        end

        permitted_data.each do |params|
          begin
            dispensations = params[:dispensations]
            program_id = params[:program_id]
            provider_id = params[:provider_id]

            program = Program.find(program_id) if program_id
            provider = provider_id ? Person.find(provider_id) : User.current.person

            DispensationService.create(program, dispensations, provider) if program && dispensations
          rescue ActiveRecord::RecordNotFound => e
            Rails.logger.error "Record not found while processing dispensation: #{e.message}"
            next
          rescue StandardError => e
            Rails.logger.error "Error processing individual dispensation: #{e.message}"
            next
          end
        end
        return true
      rescue StandardError => e
        log_error("Error in save_dispensation_data", e)
      end
    end
  end
end