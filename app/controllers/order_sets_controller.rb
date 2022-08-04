class Api::V1::OrderSetsController < ApplicationController
  before_action :set_order_set, only: %i[show update destroy]

  # GET /order_sets
  def index
    @order_sets = OrderSet.all

    render json: @order_sets
  end

  # GET /order_sets/1
  def show
    render json: @order_set
  end

  # POST /order_sets
  def create
    @order_set = OrderSet.new(order_set_params)

    if @order_set.save
      render json: @order_set, status: :created
    else
      render json: @order_set.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /order_sets/1
  def update
    if @order_set.update(order_set_params)
      render json: @order_set
    else
      render json: @order_set.errors, status: :unprocessable_entity
    end
  end

  # DELETE /order_sets/1
  def destroy
    @order_set.destroy
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_order_set
    @order_set = OrderSet.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def order_set_params
    params.require(:order_set).permit(:order_set_id, :operator, :name, :description, :creator, :date_created,
                                      :retired, :retired_by, :date_retired, :retire_reason, :changed_by, :date_changed, :uuid)
  end
end
