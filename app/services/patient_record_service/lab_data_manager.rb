# app/services/patient_record_service/lab_data_manager.rb
# frozen_string_literal: true

module PatientRecordService
  class LabDataManager < BaseSaver
    ENCOUNTER_TYPE_MAPPING = SavePatientRecordService::ENCOUNTER_TYPE_MAPPING

    def save_lab_orders_data(patient_id, record)
      save_lab_order(:labOrders, patient_id, record)
    end

    def save_lab_results_data(patient_id, record)
      save_lab_results(:labResults, patient_id, record)
    end

    def save_lab_order(data_type, patient_id, record)
      unsaved_data = record.dig(:labOrders, :unsaved)
      return false unless unsaved_data&.any?
      data_key = data_type.to_s.underscore.to_sym
      begin
        encounter_type = EncounterType.find_by_name(ENCOUNTER_TYPE_MAPPING[data_key])
        encounter_id = create_encounter(patient_id, encounter_type.id, record)
        orders = unsaved_data.map do |order_params|
          order_params = order_params.merge(encounter_id: encounter_id)
          order = Lab::OrdersService.order_test(order_params)

          tests = order.fetch(:tests)
          save_lab_results(:labResults, patient_id, record, order_params[:offline_id], tests[0][:id]) if order_params[:offline_id].present?

          person_making_request = ConceptName.find_by(name: "Person making request")&.concept_id
          test_type = ConceptName.find_by(name: "Test type")&.concept_id
          reason_for_test = ConceptName.find_by(name: "Reason for test")&.concept_id
          refer_to_HTC = ConceptName.find_by(name: "Refer to HTC")&.concept_id

          create_observation(encounter_id, {
            concept_id: person_making_request,
            value_text: order_params[:requesting_clinician],
            obs_datetime: record[:encounter_datetime],
            location_id: record[:location_id]
          })

          create_observation(encounter_id, {
            concept_id: test_type,
            value_coded: tests[0][:concept_id],
            obs_datetime: record[:encounter_datetime],
            location_id: record[:location_id]
          })

          create_observation(encounter_id, {
            concept_id: reason_for_test,
            value_coded: order_params[:reason_for_test_id],
            obs_datetime: record[:encounter_datetime],
            location_id: record[:location_id]
          })

          if order_params[:referral] == "referral"
            create_observation(encounter_id, {
              concept_id: refer_to_HTC,
              value_text: tests[0][:name],
              order_id: order.fetch(:order_id),
              obs_datetime: record[:encounter_datetime],
              location_id: record[:location_id]
            })
          end
          order
        end

        orders.each { |order| Lab::PushOrderJob.perform_later(order.fetch(:order_id)) }
        record[data_type][:unsaved] = []
        true
      rescue StandardError => e
        log_error("Failed to save #{data_type} information", e)
        false
      end
    end

    def create_observation(encounter_id, referral_params)
      encounter = Encounter.find(encounter_id)
      observation_service.create_observation(encounter, referral_params)
    end

    def save_lab_results(data_type, patient_id, record, offline_id = nil, test_obs_id = nil)
      unsaved_data = record.dig(:labOrders, :results)
      if offline_id.present? && unsaved_data&.any?
        unsaved_data = unsaved_data.select { |result| result[:offline_id] == offline_id }
      end

      return false unless unsaved_data&.any?
      data_key = data_type.to_s.underscore.to_sym

      begin
        unsaved_data.map do |order_params|
          return false if test_obs_id.blank? && order_params[:offline_id].present?
          encounter_type = EncounterType.find_by_name(ENCOUNTER_TYPE_MAPPING[data_key])
          encounter_id = create_encounter(patient_id, encounter_type.id, record)
          order_params = order_params.merge(test_id: test_obs_id) if test_obs_id
          lab_results = order_params.merge(encounter_id: encounter_id)
          Lab::ResultsService.create_results(lab_results[:test_id], lab_results)
          order_params
        end

        true
      rescue StandardError => e
        log_error("Failed to save #{data_type} information", e)
        false
      end
    end

    def void_lab_order(patient_id, record)
      data = record.dig(:labOrders, :voided)
      return false unless data&.any?
      data.map do |item|
        Lab::OrdersService.void_order(item[:orderId], item[:reason])
        Lab::VoidOrderJob.perform_later(item[:orderId])
      end
      record[:labOrders][:voided] = []
      true
    end
  end
end