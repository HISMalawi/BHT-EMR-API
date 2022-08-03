class Api::V1::EncounterProvidersController < ApplicationController
  before_action :set_encounter_provider, only: %i[show update destroy]

  # GET /encounter_providers
  def index
    @encounter_providers = EncounterProvider.all

    render json: @encounter_providers
  end

  # GET /encounter_providers/1
  def show
    render json: @encounter_provider
  end

  # POST /encounter_providers
  def create
    @encounter_provider = EncounterProvider.new(encounter_provider_params)

    if @encounter_provider.save
      render json: @encounter_provider, status: :created
    else
      render json: @encounter_provider.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /encounter_providers/1
  def update
    if @encounter_provider.update(encounter_provider_params)
      render json: @encounter_provider
    else
      render json: @encounter_provider.errors, status: :unprocessable_entity
    end
  end

  # DELETE /encounter_providers/1
  def destroy
    @encounter_provider.destroy
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_encounter_provider
    @encounter_provider = EncounterProvider.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def encounter_provider_params
    params.require(:encounter_provider).permit(:encounter_id, :provider_id, :encounter_role_id, :creator,
                                               :date_created, :changed_by, :date_changed, :voided, :date_voided, :voided_by, :void_reason, :uuid)
  end
end
