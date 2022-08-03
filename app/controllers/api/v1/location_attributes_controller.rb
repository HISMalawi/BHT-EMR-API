class Api::V1::LocationAttributesController < ApplicationController
  before_action :set_location_attribute, only: %i[show update destroy]

  # GET /location_attributes
  def index
    @location_attributes = LocationAttribute.all

    render json: @location_attributes
  end

  # GET /location_attributes/1
  def show
    render json: @location_attribute
  end

  # POST /location_attributes
  def create
    @location_attribute = LocationAttribute.new(location_attribute_params)

    if @location_attribute.save
      render json: @location_attribute, status: :created
    else
      render json: @location_attribute.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /location_attributes/1
  def update
    if @location_attribute.update(location_attribute_params)
      render json: @location_attribute
    else
      render json: @location_attribute.errors, status: :unprocessable_entity
    end
  end

  # DELETE /location_attributes/1
  def destroy
    @location_attribute.destroy
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_location_attribute
    @location_attribute = LocationAttribute.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def location_attribute_params
    params.require(:location_attribute).permit(:location_id, :attribute_type_id, :value_reference, :uuid, :creator,
                                               :date_created, :changed_by, :date_changed, :voided, :voided_by, :date_voided, :void_reason)
  end
end
