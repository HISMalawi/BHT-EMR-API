class Api::V1::ProviderAttributesController < ApplicationController
  before_action :set_provider_attribute, only: %i[show update destroy]

  # GET /provider_attributes
  def index
    @provider_attributes = ProviderAttribute.all

    render json: @provider_attributes
  end

  # GET /provider_attributes/1
  def show
    render json: @provider_attribute
  end

  # POST /provider_attributes
  def create
    @provider_attribute = ProviderAttribute.new(provider_attribute_params)

    if @provider_attribute.save
      render json: @provider_attribute, status: :created
    else
      render json: @provider_attribute.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /provider_attributes/1
  def update
    if @provider_attribute.update(provider_attribute_params)
      render json: @provider_attribute
    else
      render json: @provider_attribute.errors, status: :unprocessable_entity
    end
  end

  # DELETE /provider_attributes/1
  def destroy
    @provider_attribute.destroy
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_provider_attribute
    @provider_attribute = ProviderAttribute.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def provider_attribute_params
    params.require(:provider_attribute).permit(:provider_id, :attribute_type_id, :value_reference, :uuid, :creator,
                                               :date_created, :changed_by, :date_changed, :voided, :voided_by, :date_voided, :void_reason)
  end
end
