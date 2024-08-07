# frozen_string_literal: true

module Lab
  class OrdersController < ApplicationController
    def create
      order_params_list = params.require(:orders)
      orders = order_params_list.map do |order_params|
        OrdersService.order_test(order_params)
      end

      render json: orders, status: :created
    end

    def update
      specimen = params.require(:specimen).permit(:concept_id)

      order = OrdersService.update_order(params[:id], specimen: specimen)

      render json: order
    end

    def index
      filters = params.permit(%i[patient_id accession_number date status])

      render json: OrdersSearchService.find_orders(filters)
    end

    def destroy
      OrdersService.void_order(params[:id], params[:reason])

      render status: :no_content
    end
  end
end
