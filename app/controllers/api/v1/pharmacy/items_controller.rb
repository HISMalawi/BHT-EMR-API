# frozen_string_literal: true

class Api::V1::Pharmacy::ItemsController < ApplicationController
  # GET /pharmacy/items[?drug_id=]
  def index
    items = service.find_batch_items(params.permit(:drug_id, :current_quantity))
    render json: paginate(items)
  end

  def show
    render json: item
  end

  def update
    permitted_params = params.permit(%i[current_quantity delivered_quantity pack_size expiry_date delivery_date reason])
    raise InvalidParameterError, 'reason is required' if permitted_params[:reason].blank?

    item = service.edit_batch_item(params[:id], permitted_params)

    if item.errors.empty?
      render json: item
    else
      render json: { errors: item.errors }, status: :bad_request
    end
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
