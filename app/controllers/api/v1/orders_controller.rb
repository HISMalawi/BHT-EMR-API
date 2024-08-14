# frozen_string_literal: true

require 'zebra_printer/init'

module Api
  module V1
    class OrdersController < ApplicationController
      before_action :authenticate, except: %i[print_radiology_order]
      after_action :refresh_dashboard, only: %i[destroy]

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
        params = destroy_params
        order = Order.find(params[:id])

        ActiveRecord::Base.transaction do
          order.void(params[:reason])
          Observation.where(order_id: order.id).each { |obs| obs.void(params[:reason])}
        end
        render json: order, status: :no_content

      rescue ActiveRecord::RecordNotFound
        render json: { errors: "Order ##{params[:id]} not found" }, status: :not_found
      end

      def radiology_order
        render json: RadiologyService::Investigation.create_order(radiology_params), status: 201
      end

      def print_radiology_order
        printer_commands = RadiologyService::OrderLabel.new(params.permit(:accession_number, :order_id)).print
        send_data(printer_commands, type: 'application/label; charset=utf-8',
                                    stream: false,
                                    filename: "#{SecureRandom.hex(24)}.lbl",
                                    disposition: 'inline')
      end

      private

      def radiology_params
        params.permit(:encounter_id, :concept_id, :instructions, :start_date, :orderer, :accession_number, :provider)
      end

      def destroy_params
        params.require(%i[id reason])
        params.permit(%i[id reason])
      end

      def refresh_dashboard
        ImmunizationReportJob.perform_later(1.year.ago.to_date.to_s, Date.today.to_s, User.current.location_id)
      end
    end
  end
end
