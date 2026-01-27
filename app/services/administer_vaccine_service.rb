# frozen_string_literal: true

module AdministerVaccineService
  class << self 
    include ModelUtils

    def administer_vaccine(encounter_id, drug_orders, program_id, obs_archetypes, provider_id, location_id = nil)
      validate_program_and_encounter!(program_id, encounter_id)
      validate_batch_numbers!(drug_orders)

      ActiveRecord::Base.transaction do
        begin
          # Create drug orders
          orders = DrugOrderService.create_drug_orders(
            encounter: Encounter.find(encounter_id),
            drug_orders: drug_orders
          )

          # Create dispensations
          dispensation = create_dispensations(orders, drug_orders, program_id, provider_id)
          raise ActiveRecord::Rollback unless dispensation

          # Create observations
          observations = create_observations(encounter_id, obs_archetypes, location_id)
          raise ActiveRecord::Rollback if observations.any?(&:nil?)

        rescue StandardError => e
          Rails.logger.error("Failed in administer_vaccine: #{e.message}")
          Rails.logger.error(e.backtrace.join("\n"))
          raise ActiveRecord::Rollback
        end
      end
    end
    def validate_program_and_encounter!(program_id, encounter_id)
      program = Program.find(program_id)
      unless program.name == 'IMMUNIZATION PROGRAM'
        raise StandardError, "Not an immunization program ##{program.program_id}"
      end

      encounter = Encounter.find(encounter_id)
      unless encounter.type.name == 'TREATMENT'
        raise StandardError, "Not a treatment encounter ##{encounter.encounter_id}"
      end
    end

    def validate_batch_numbers!(drug_orders)
      drug_orders.each do |drug_order|
        next if drug_order["batch_number"] == "Unknown"
        unless PharmacyBatch.find_by(batch_number: drug_order["batch_number"]).present?
          raise StandardError, "Batch number #{drug_order["batch_number"]} does not exist and its not even set to unknown"
        end
      end
    end

    def create_dispensations(orders, drug_orders, program_id, provider_id)
      dispensations = []
      program = Program.find(program_id)
      provider = provider_id ? Person.find(provider_id) : User.current.person

      orders.each do |order|
        drug_orders.each do |drug_order|
          if drug_order["drug_inventory_id"] == order.drug_inventory_id
            dispensations << {
              drug_order_id: order.order_id,
              date: drug_order["start_date"],
              quantity: 1
            }
          end
        end
      end

      DispensationService.create(program, dispensations, provider)
    end

    def create_observations(encounter_id, obs_archetypes, location_id)
      encounter = Encounter.find(encounter_id)
      obs_archetypes.map do |archetype|
        archetype[:location_id] = location_id
        service.create_observation(encounter, archetype.permit!)
      end
    end

    def service
      ObservationService.new
    end
  end
end