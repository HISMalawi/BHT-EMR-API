# app/services/patient_record_service/medication_order_saver.rb
# frozen_string_literal: true

module PatientRecordService
  class MedicationOrderSaver < BaseSaver
    ENCOUNTER_TYPE_MAPPING = SavePatientRecordService::ENCOUNTER_TYPE_MAPPING

    def save_medication_order(patient_id, record)
      orders_unsaved = record.dig(:MedicationOrder, :unsaved)
      return false unless orders_unsaved&.any?

      begin
        ActiveRecord::Base.transaction do
          orders_unsaved.each do |order|
            next unless order
            encounter_type = EncounterType.find_by_name(ENCOUNTER_TYPE_MAPPING[:treatment])
            encounter_id = create_encounter(patient_id, encounter_type.id, record)
            encounter = Encounter.find(encounter_id)

            unless encounter.type.name == 'TREATMENT'
              Rails.logger.warn("Unexpected encounter type: #{encounter.type.name} for encounter ##{encounter.encounter_id}")
              next
            end
            saved_drug_orders =DrugOrderService.create_drug_orders(encounter: encounter, drug_orders: [order])
            save_dispensation_data(patient_id, record, saved_drug_orders[0][:order_id], order[:dispensation])
          end
        end
        return true
      rescue StandardError => e
        log_error("Failed to create medication order", e)
        raise # Re-raise if you want the transaction to rollback
      end
    end
    def save_dispensation_data(patient_id, record, order_id = nil, dispensation_data = nil)
      begin
        permitted_data = build_permitted_data(patient_id, record, order_id, dispensation_data)
        return false unless permitted_data&.any?

        process_dispensations(permitted_data,record)
        return true
      rescue StandardError => e
        log_error("Error in save_dispensation_data", e)
        return false
      end
    end

    private

    def build_permitted_data(patient_id, record, order_id, dispensation_data)
      if dispensation_data.nil? && order_id.nil?
        extract_unsaved_dispensations(record)
      else
        build_single_dispensation(patient_id, order_id, dispensation_data)
      end
    end

    def extract_unsaved_dispensations(record)
      unsaved_data = record.dig(:MedicationOrder, :saved)
      return [] unless unsaved_data&.any?

      unsaved_data.flat_map do |dispensation_params|
        next [] unless dispensation_params[:dispensation]

        dispensation_params[:dispensation].map do |dispensation|
          {
            provider_id: dispensation[:provider_id],
            program_id: dispensation[:program_id],
            patient_id: dispensation[:patient_id],
            dispensations: [
              {
                drug_order_id: dispensation[:drug_order_id],
                date: dispensation[:date],
                quantity: dispensation[:quantity]
              }
            ]
          }
        end
      end
    end

    def build_single_dispensation(patient_id, order_id, dispensation_data)
      return [] if dispensation_data.nil?
      
      [{
        provider_id: dispensation_data[:provider_id],
        program_id: dispensation_data[:program_id],
        patient_id: patient_id,
        dispensations: [{
          drug_order_id: order_id,
          date: dispensation_data[:date],
          quantity: dispensation_data[:quantity]
        }]
      }]
    end

    def process_dispensations(permitted_data, record)
      permitted_data.each do |params|
        process_single_dispensation(params, record)
      end
    end

    def process_single_dispensation(params, record)
      dispensations = params[:dispensations]
      program_id = params[:program_id]
      provider_id = params[:provider_id]
      return unless dispensations&.any?

      program = find_program(program_id)
      provider = find_provider(provider_id)

      return unless program && provider

      DispensationService.create(program, dispensations, provider, record[:location_id])
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "Record not found while processing dispensation: #{e.message}"
    rescue StandardError => e
      Rails.logger.error "Error processing individual dispensation: #{e.message}"
    end

    def find_program(program_id)
      return nil unless program_id
      Program.find(program_id)
    rescue ActiveRecord::RecordNotFound
      Rails.logger.error "Program not found: #{program_id}"
      nil
    end

    def find_provider(provider_id)
      provider_id ? Person.find(provider_id) : User.current&.person
    rescue ActiveRecord::RecordNotFound
      Rails.logger.error "Provider not found: #{provider_id}"
      nil
    end
  end
end