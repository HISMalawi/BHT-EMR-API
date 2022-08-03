class Api::V1::EncounterRolesController < ApplicationController
  before_action :set_encounter_role, only: %i[show update destroy]

  # GET /encounter_roles
  def index
    @encounter_roles = EncounterRole.all

    render json: @encounter_roles
  end

  # GET /encounter_roles/1
  def show
    render json: @encounter_role
  end

  # POST /encounter_roles
  def create
    @encounter_role = EncounterRole.new(encounter_role_params)

    if @encounter_role.save
      render json: @encounter_role, status: :created
    else
      render json: @encounter_role.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /encounter_roles/1
  def update
    if @encounter_role.update(encounter_role_params)
      render json: @encounter_role
    else
      render json: @encounter_role.errors, status: :unprocessable_entity
    end
  end

  # DELETE /encounter_roles/1
  def destroy
    @encounter_role.destroy
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_encounter_role
    @encounter_role = EncounterRole.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def encounter_role_params
    params.require(:encounter_role).permit(:name, :description, :creator, :date_created, :changed_by, :date_changed,
                                           :retired, :retired_by, :date_retired, :retire_reason, :uuid)
  end
end
