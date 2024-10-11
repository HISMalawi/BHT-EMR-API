# frozen_string_literal: true

require "zebra_printer/init"

module Api
  module V1
    class OrdersController < ApplicationController
      before_action :authenticate, except: %i[print_radiology_order]

      def index; end

      def show
        render json: Order.find(params[:id])
      end

      def create
        create_params = params.require(:order).permit(
          :order_type_id, :concept_id, :encounter_id, :instructions, :start_date,
          :auto_expire_date, :creator, :accession_number, :patient_id
        )

        create_params[:orderer] ||= User.current.id

        order = Order.create create_params
        if order.errors.empty?
          render json: order, status: :created
        else
          render json: order.errors, status: :bad_request
        end
      end

      def update
        update_params = params.require(:order).permit(
          :order_type_id, :concept_id, :encounter_id, :instructions, :start_date,
          :auto_expire_date, :creator, :accession_number
        )

        order = Order.find(params[:id])
        if order.update update_params
          render json: order
        else
          render json: order.errors, status: :bad_request
        end
      end

      def destroy
        drug = Drug.find(params[:id])
        if drug.destroy
          render status: :no_content
        else
          render json: { errors: drug.errors }, status: :internal_server_error
        end
      end

      def radiology_order
        render json: RadiologyService::Investigation.create_order(radiology_params), status: 201
      end

      def print_radiology_order
        render_zpl(RadiologyService::OrderLabel.new(params.permit(:accession_number, :order_id)))
      end

      private

      def radiology_params
        params.permit(:encounter_id, :concept_id, :instructions, :start_date, :orderer, :accession_number, :provider)
      end
    end
  end
end
