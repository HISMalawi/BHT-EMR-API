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
          
          start_date = 1.year.ago.to_date.to_s
          end_date = Date.today.to_s

      
          ImmunizationReportJob.perform_later(start_date, end_date)

          render json: orders, status: :created
        end

        def add_adverse_effects
          encounter_id, adverse_effects, program_id = params.require(%i[encounter_id adverse_effects program_id])
  
          encounter = Encounter.find(encounter_id)
  
          unless encounter.type.name == 'IMMUNIZATION FOLLOW UP'
            return render json: { errors: "Not an immunization encounter ##{encounter.encounter_id}" },
                          status: :bad_request
          end
  
          created_observations = service.add_adverse_effects(
            encounter: encounter, 
            adverse_effects: adverse_effects
          )
  
          render json: created_observations, status: :created
        end
  
        private
        
        def service
          ImmunizationService::ClientAdverseEffect.new
        end
    end
  end
end


