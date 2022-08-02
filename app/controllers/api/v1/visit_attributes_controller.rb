class Api::V1::VisitAttributesController < ApplicationController
  before_action :set_visit_attribute, only: [:show, :update, :destroy]

  # GET /visit_attributes
  def index
    @visit_attributes = VisitAttribute.all

    render json: @visit_attributes
  end

  # GET /visit_attributes/1
  def show
    render json: @visit_attribute
  end

  # POST /visit_attributes
  def create
    @visit_attribute = VisitAttribute.new(visit_attribute_params)

    if @visit_attribute.save
      render json: @visit_attribute, status: :created, location: @visit_attribute
    else
      render json: @visit_attribute.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /visit_attributes/1
  def update
    if @visit_attribute.update(visit_attribute_params)
      render json: @visit_attribute
    else
      render json: @visit_attribute.errors, status: :unprocessable_entity
    end
  end

  # DELETE /visit_attributes/1
  def destroy
    @visit_attribute.destroy
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_visit_attribute
      @visit_attribute = VisitAttribute.find(params[:id])
    end

    # Only allow a trusted parameter "white list" through.
    def visit_attribute_params
      params.require(:visit_attribute).permit(:visit_id, :attribute_type_id, :value_reference, :uuid, :creator, :date_created, :changed_by, :voided, :voided_by, :date_voided, :void_reason)
    end
end
