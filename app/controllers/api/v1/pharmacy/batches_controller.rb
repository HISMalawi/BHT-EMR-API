# frozen_string_literal: true

module Api
  module V1
    module Pharmacy
      class BatchesController < ApplicationController
        #  GET /pharmacy/batches
        def index
          render json: paginate(service.find_all_batches)
        end

        # GET /pharmacy/batches/:batch_number
        def show
          render json: service.find_batch_by_batch_number(params[:id])
        end


        # POST /pharmacy/batches
        #
        # Request structure:
        #
        #   {
        #     batch_number: string,
        #     drugs: [
        #       {
        #          drug_id: *int,
        #          pack_size: int,
        #          quantity: *double,
        #          expiry_date: *string, # Date in 'YYYY-MM-DD'
        #          delivery_date: string, # Same as above (defaults to today)
        #          barcode: string
        #       }
        #     ]
        #   }
        #


        def create
          batch_params = params['_json']          
          user_program = User.current.programs { |x| x["name"] == "IMMUNIZATION PROGRAM" }
          if user_program.present?
            location_id = User.current.location_id
            batch_params.each { |param| param["location_id"] = location_id }
          end           
          render json: service.create_batches(batch_params), status: :created
        end
        

        def update
          params[:batch_number] = params[:id]
          create
        end

        # DELETE /pharmacy/batches/:batch_number
        def destroy
          service.void_batch(params[:id], params.require(:reason))

          render status: :no_content
        end

        private

        def service
          StockManagementService.new
        end
      end
    end
  end
end
