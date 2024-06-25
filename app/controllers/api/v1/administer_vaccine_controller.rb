module Api
  module V1
    class AdministerVaccineController < ApplicationController
        
        def administer_vaccine
          encounter_id, drug_orders, program_id = params.require(%i[encounter_id drug_orders program_id])

          encounter = Encounter.find(encounter_id)

          unless encounter.type.name = 'IMMUNIZATION RECORD'
            return render json: { errors: "Not an immunization encounter ##{encounter.encounter_id}"},
                          status: :bad_request
          end

          orders = DrugOrderService.create_drug_orders(encounter: , drug_orders:)

          program = Program.find(program_id)
          provider = params[:provider_id] ? Person.find(params[:provider_id]) : User.current.person

          dispensations = []

          orders.each do |order|
            drug_orders.each do |drug_order|
              if drug_order["drug_inventory_id"] == order.drug_inventory_id
                dispensations << { drug_order_id: order.order_id, date: drug_order["start_date"], quantity: 1 }
              end
            end
          end

          DispensationService.create(program, dispensations, provider)

                  # Broadcast to the ImmunizationReportChannel
          ActionCable.server.broadcast(
            'immunization_report',
            {
              action: 'fetch_data',
              start_date: '2024-01-01',
              end_date: '2024-12-31'
            }
          )
          
          render json: orders, status: :created
        end
    end
  end
end


