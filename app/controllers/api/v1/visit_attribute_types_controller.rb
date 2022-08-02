class Api::V1::VisitAttributeTypesController < ApplicationController
  before_action :set_visit_attribute_type, only: %i[show update destroy]

  # GET /visit_attribute_types
  def index
    @visit_attribute_types = VisitAttributeType.all

    render json: @visit_attribute_types
  end

  # GET /visit_attribute_types/1
  def show
    render json: @visit_attribute_type
  end

  # POST /visit_attribute_types
  def create
    @visit_attribute_type = VisitAttributeType.new(visit_attribute_type_params)

    if @visit_attribute_type.save
      render json: @visit_attribute_type, status: :created, location: @visit_attribute_type
    else
      render json: @visit_attribute_type.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /visit_attribute_types/1
  def update
    if @visit_attribute_type.update(visit_attribute_type_params)
      render json: @visit_attribute_type
    else
      render json: @visit_attribute_type.errors, status: :unprocessable_entity
    end
  end

  # DELETE /visit_attribute_types/1
  def destroy
    @visit_attribute_type.destroy
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_visit_attribute_type
    @visit_attribute_type = VisitAttributeType.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def visit_attribute_type_params
    params.require(:visit_attribute_type).permit(:name, :description, :datatype, :datatype_config,
                                                 :preferred_handler, :handler_config, :min_occurs, :max_occurs, :creator, :date_created, :changed_by, :date_changed, :retired, :retired_by, :date_retired, :retire_reason, :uuid)
  end
end
