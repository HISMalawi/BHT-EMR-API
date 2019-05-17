# frozen_string_literal: true

class Api::V1::Pharmacy::ItemsController < ApplicationController
  # GET /pharmacy/items[?drug_id=]
  def index
    items = service.find_batch_items(params.permit(:drug_id, :current_quantity))
    render json: paginate(items)
  end

  def show
    render json: service.find_batch_item_by_id(params[:id])
  end

  def update
    permitted_params = params.permit(%i[delivered_quantity expiry_date delivery_date])
    item = service.update_batch_item(params[:id], permitted_params)

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

  private

  def service
    StockManagementService.new
  end
end
