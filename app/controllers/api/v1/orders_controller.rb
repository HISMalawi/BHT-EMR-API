class Api::V1::OrdersController < ApplicationController
  def index
  end

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
    if drug.destroy()
      render status: :no_content
    else
      render json: { errors: drug.errors }, status: :internal_server_error
    end
  end
end
