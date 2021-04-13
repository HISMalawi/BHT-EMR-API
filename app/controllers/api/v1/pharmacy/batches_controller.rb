# frozen_string_literal: true

class Api::V1::Pharmacy::BatchesController < ApplicationController
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
  #          delivery_date: string # Same as above (defaults to today)
  #       }
  #     ]
  #   }
  #
  def create
    batch_number, items = params.require(%i[batch_number items])
    render json: service.add_items_to_batch(batch_number, items), status: :created
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
