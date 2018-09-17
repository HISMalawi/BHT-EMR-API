class Api::V1::OrdersController < ApplicationController
  def index
  end

  def show
    render json: Order.find(params[:id])
  end

  def create
    params.require(:order).permit()
  end

  def update
  end

  def destroy
    drug = Drug.find(params[:id])
    if drug.destroy()
      render status: :no_content
    else
      render json: { errors: drug.errors }, status: :internal_server_error
    end
  end
end
