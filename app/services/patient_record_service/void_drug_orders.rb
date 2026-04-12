# frozen_string_literal: true

module PatientRecordService
  class VoidDrugOrders < BaseSaver
    def void_drug_orders(patient_id, record)
      begin
        unsaved_data = record.dig(:voidedDrugOders, :unsaved)
        return true if unsaved_data.blank?

        unsaved_data.each do |void_params|
          # Permit incoming batch data
          params = void_params.permit(
            :provider_id,
            :program_id,
            :patient_id,
            voidedDrugOders: [:drug_order_id, :date, :reason]
          )

          # Loop through each medication in the batch
          params[:voidedDrugOders].each do |void_item|
            order = Order.find_by(order_id: void_item[:drug_order_id])
            next unless order

            # Replicating your original void_drug_order logic
            order.update!(
              voided: 1,
              void_reason: void_item[:reason] || 'Out of stock',
              voided_by: params[:provider_id] || User.current&.id,
              date_voided: void_item[:date] || Time.now
            )
          end
        end
        
        return true
      rescue StandardError => e
        log_error("Error in void drug orders", e)
        false
      end
    end
  end
end
