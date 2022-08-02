class ProviderAttributeTypesController < ApplicationController
  before_action :set_provider_attribute_type, only: [:show, :update, :destroy]

  # GET /provider_attribute_types
  def index
    @provider_attribute_types = ProviderAttributeType.all

    render json: @provider_attribute_types
  end

  # GET /provider_attribute_types/1
  def show
    render json: @provider_attribute_type
  end

  # POST /provider_attribute_types
  def create
    @provider_attribute_type = ProviderAttributeType.new(provider_attribute_type_params)

    if @provider_attribute_type.save
      render json: @provider_attribute_type, status: :created, location: @provider_attribute_type
    else
      render json: @provider_attribute_type.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /provider_attribute_types/1
  def update
    if @provider_attribute_type.update(provider_attribute_type_params)
      render json: @provider_attribute_type
    else
      render json: @provider_attribute_type.errors, status: :unprocessable_entity
    end
  end

  # DELETE /provider_attribute_types/1
  def destroy
    @provider_attribute_type.destroy
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_provider_attribute_type
      @provider_attribute_type = ProviderAttributeType.find(params[:id])
    end

    # Only allow a trusted parameter "white list" through.
    def provider_attribute_type_params
      params.require(:provider_attribute_type).permit(:name, :description, :datatype, :datatype_config, :preferred_handler, :handler_config, :min_occurs, :max_occurs, :creator, :date_created, :changed_by, :date_changed, :retired, :retired, :retired_by, :date_retired, :retire_reason, :uuid)
    end
end
