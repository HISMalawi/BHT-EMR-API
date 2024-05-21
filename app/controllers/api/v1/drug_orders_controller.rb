# frozen_string_literal: true

require 'utils/remappable_hash'

module Api
  module V1
    class DrugOrdersController < ApplicationController
      def index
        filters = params.permit DrugOrderService::FIND_FILTERS + [:date]

        drug_orders = DrugOrderService.find(filters).order(Arel.sql('`orders`.`date_created`'))

        render json: paginate(drug_orders.includes(%i[order], drug: [:barcodes]))
      end

      # POST /drug_orders
      #
      # Create drug orders in bulk
      #
      # Required params:
      def create
        encounter_id, drug_orders = params.require(%i[encounter_id drug_orders])

        encounter = Encounter.find(encounter_id)
        unless encounter.type.name == 'TREATMENT'
          return render json: { errors: "Not a treatment encounter ##{encounter.encounter_id}" },
                        status: :bad_request
        end

        orders = DrugOrderService.create_drug_orders(encounter:,
                                                     drug_orders:)
        render json: orders, status: :created
      end

      def update
        quantity_updates = params.require :drug_orders

        orders, error = DrugOrderService.update_drug_orders quantity_updates

        if error
          render json: error, status: :bad_request if error
        else
          render json: orders, status: :created
        end
      end

      def destroy
        DrugOrder.find(params[:id])

        if drug_order.void
          render status: :no_content
        else
          render json: drug_order.errors, status: :internal_server_error
        end
      end
    end
  end
end
