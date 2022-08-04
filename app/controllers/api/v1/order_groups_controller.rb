class Api::V1::OrderGroupsController < ApplicationController
  before_action :set_order_group, only: %i[show update destroy]

  # GET /order_groups
  def index
    @order_groups = OrderGroup.all

    render json: @order_groups
  end

  # GET /order_groups/1
  def show
    render json: @order_group
  end

  # POST /order_groups
  def create
    @order_group = OrderGroup.new(order_group_params)

    if @order_group.save
      render json: @order_group, status: :created
    else
      render json: @order_group.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /order_groups/1
  def update
    if @order_group.update(order_group_params)
      render json: @order_group
    else
      render json: @order_group.errors, status: :unprocessable_entity
    end
  end

  # DELETE /order_groups/1
  def destroy
    @order_group.destroy
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_order_group
    @order_group = OrderGroup.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def order_group_params
    params.require(:order_group).permit(:order_group_id, :order_set_id, :patient_id, :encounter_id, :creator,
                                        :date_created, :voided, :voided_by, :date_voided, :void_reason, :changed_by, :uuid)
  end
end
