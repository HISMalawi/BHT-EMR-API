class Api::V1::ProvidermanagementProviderRolesController < ApplicationController
  before_action :set_providermanagement_provider_role, only: [:show, :update, :destroy]

  # GET /providermanagement_provider_roles
  def index
    @providermanagement_provider_roles = ProvidermanagementProviderRole.all

    render json: @providermanagement_provider_roles
  end

  # GET /providermanagement_provider_roles/1
  def show
    render json: @providermanagement_provider_role
  end

  # POST /providermanagement_provider_roles
  def create
    @providermanagement_provider_role = ProvidermanagementProviderRole.new(providermanagement_provider_role_params)

    if @providermanagement_provider_role.save
      render json: @providermanagement_provider_role, status: :created, location: @providermanagement_provider_role
    else
      render json: @providermanagement_provider_role.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /providermanagement_provider_roles/1
  def update
    if @providermanagement_provider_role.update(providermanagement_provider_role_params)
      render json: @providermanagement_provider_role
    else
      render json: @providermanagement_provider_role.errors, status: :unprocessable_entity
    end
  end

  # DELETE /providermanagement_provider_roles/1
  def destroy
    @providermanagement_provider_role.destroy
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_providermanagement_provider_role
      @providermanagement_provider_role = ProvidermanagementProviderRole.find(params[:id])
    end

    # Only allow a trusted parameter "white list" through.
    def providermanagement_provider_role_params
      params.require(:providermanagement_provider_role).permit(:name, :description, :date_created, :changed_by, :date_changed, :retired, :retired_by, :date_retired, :retire_reason, :uuid)
    end
end
