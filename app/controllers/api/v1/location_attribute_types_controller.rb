class Api::V1::LocationAttributeTypesController < ApplicationController
  before_action :set_location_attribute_type, only: %i[show update destroy]

  # GET /location_attribute_types
  def index
    @location_attribute_types = LocationAttributeType.all

    render json: @location_attribute_types
  end

  # GET /location_attribute_types/1
  def show
    render json: @location_attribute_type
  end

  # POST /location_attribute_types
  def create
    @location_attribute_type = LocationAttributeType.new(location_attribute_type_params)

    if @location_attribute_type.save
      render json: @location_attribute_type, status: :created
    else
      render json: @location_attribute_type.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /location_attribute_types/1
  def update
    if @location_attribute_type.update(location_attribute_type_params)
      render json: @location_attribute_type
    else
      render json: @location_attribute_type.errors, status: :unprocessable_entity
    end
  end

  # DELETE /location_attribute_types/1
  def destroy
    @location_attribute_type.destroy
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_location_attribute_type
    @location_attribute_type = LocationAttributeType.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def location_attribute_type_params
    params.require(:location_attribute_type).permit(:name, :description, :datatype, :datatype_config,
                                                    :preferred_handler, :handler_config, :min_occurs, :max_occurs, :creator, :date_created, :changed_by, :date_changed, :retired, :date_retired, :retire_reason, :uuid)
  end
end
