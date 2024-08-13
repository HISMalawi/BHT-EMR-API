# frozen_string_literal: true

module Api
  module V1
    module Pharmacy
      class ItemsController < ApplicationController
        # GET /pharmacy/items[?drug_id=]
        def index
          user_program = User.current.programs.detect { |x| x["name"] == "IMMUNIZATION PROGRAM" }
          permitted_params = params.permit(:drug_id, :current_quantity, :start_date, :end_date, :batch_number, :drug_name)
          
          if user_program.present?
            permitted_params = permitted_params.merge("location_id" => User.current.location_id)
          end
          
          items = service.find_batch_items(permitted_params)
          render json: paginate(items)
        end
        

        def show
          render json: item
        end

        def update
          permitted_params = params.permit(%i[current_quantity delivered_quantity pack_size expiry_date delivery_date
                                              reason])
          raise InvalidParameterError, 'reason is required' if permitted_params[:reason].blank?

          item = service.edit_batch_item(params[:id], permitted_params)

          if item.errors.empty?
            render json: item
          else
            render json: { errors: item.errors }, status: :bad_request
          end
        end

        def batch_update
          permitted_params = params.permit(:verification_date, :reason,
                                           items: %i[id current_quantity delivered_quantity pack_size expiry_date delivery_date reason])
          raise InvalidParameterError, 'reason is required' if permitted_params[:reason].blank?

          service.batch_update_items(permitted_params)

          render status: :no_content
        end

        def destroy
          reason = params.require(:reason)
          service.void_batch_item(params[:id], reason)
          render status: :no_content
        end

        def earliest_expiring
          permitted_params = params.permit(:drug_id)
          item = service.find_earliest_expiring_item(permitted_params)
          render json: item
        end

        # Reallocate item to some other facility
        def reallocate
          code, quantity, location_id, reason = params.require(%i[reallocation_code quantity location_id reason])
          raise InvalidParameterError, 'reason is required' if reason.blank?

          date = params[:date]&.to_date || Date.today

          reallocation = service.reallocate_items(code, params[:item_id], quantity, location_id, date, reason)

          render json: reallocation, status: :created
        end

        def dispose
          code, quantity, reason = params.require(%i[reallocation_code quantity reason])
          raise InvalidParameterError, 'reason is required' if reason.blank?

          date = params['date']&.to_date || Date.today

          disposal = service.dispose_item(code, params[:item_id], quantity, date, reason)

          render json: disposal, status: :created
        end

        private

        def service
          StockManagementService.new
        end

        def item
          service.find_batch_item_by_id(params[:id])
        end
      end
    end
  end
end
