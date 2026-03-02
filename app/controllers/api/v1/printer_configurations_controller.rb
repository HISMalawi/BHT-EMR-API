# app/controllers/api/v1/printer_configurations_controller.rb
module Api
  module V1
    class PrinterConfigurationsController < ApplicationController
      # GET /api/v1/printer_configurations
      def index
        if params[:location_id].present?
          @printer_configurations = CouchdbPrinterService.find_by_location(params[:location_id])
        else
          @printer_configurations = CouchdbPrinterService.get_all_printers
        end
        render json: @printer_configurations
      end

      # GET /api/v1/printer_configurations/:id
      def show
        @printer_configuration = CouchdbPrinterService.get_printer(params[:id])
        
        if @printer_configuration
          render json: @printer_configuration
        else
          render json: { error: 'Printer configuration not found' }, status: :not_found
        end
      end

      # POST /api/v1/printer_configurations
      def create
        result = CouchdbPrinterService.create_printer(printer_configurations_params)

        if result[:success]
          render json: result[:data], status: :created
        else
          render json: { errors: [result[:error]] }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/printer_configurations/:id
      def update
        result = CouchdbPrinterService.update_printer(params[:id], printer_configurations_params)

        if result[:success]
          render json: result[:data]
        elsif result[:error] == 'Printer configuration not found'
          render json: { error: result[:error] }, status: :not_found
        else
          render json: { errors: [result[:error]] }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/printer_configurations/:id
      def destroy
        result = CouchdbPrinterService.delete_printer(params[:id])

        if result[:success]
          head :no_content
        elsif result[:error] == 'Printer configuration not found'
          render json: { error: result[:error] }, status: :not_found
        else
          render json: { errors: [result[:error]] }, status: :unprocessable_entity
        end
      end

      private

      def printer_configurations_params
        params.require(:printer_configuration).permit(:ip_address, :location_id, :printer_name, :port)
      end
    end
  end
end