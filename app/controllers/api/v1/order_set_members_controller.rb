class Api::V1::OrderSetMembersController < ApplicationController
  before_action :set_order_set_member, only: %i[show update destroy]

  # GET /order_set_members
  def index
    @order_set_members = OrderSetMember.all

    render json: @order_set_members
  end

  # GET /order_set_members/1
  def show
    render json: @order_set_member
  end

  # POST /order_set_members
  def create
    @order_set_member = OrderSetMember.new(order_set_member_params)

    if @order_set_member.save
      render json: @order_set_member, status: :created
    else
      render json: @order_set_member.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /order_set_members/1
  def update
    if @order_set_member.update(order_set_member_params)
      render json: @order_set_member
    else
      render json: @order_set_member.errors, status: :unprocessable_entity
    end
  end

  # DELETE /order_set_members/1
  def destroy
    @order_set_member.destroy
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_order_set_member
    @order_set_member = OrderSetMember.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def order_set_member_params
    params.require(:order_set_member).permit(:order_set_member_id, :order_type, :order_template,
                                             :order_template_type, :order_set_id, :sequence_number, :concept_id, :creator, :date_created, :retired, :retired_by, :date_retired, :retire_reason, :changed_by, :date_changed, :uuid)
  end
end
