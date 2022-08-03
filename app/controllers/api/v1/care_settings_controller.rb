class Api::V1::CareSettingsController < ApplicationController
  before_action :set_care_setting, only: %i[show update destroy]

  # GET /care_settings
  def index
    @care_settings = CareSetting.all

    render json: @care_settings
  end

  # GET /care_settings/1
  def show
    render json: @care_setting
  end

  # POST /care_settings
  def create
    @care_setting = CareSetting.new(care_setting_params)

    if @care_setting.save
      render json: @care_setting, status: :created
    else
      render json: @care_setting.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /care_settings/1
  def update
    if @care_setting.update(care_setting_params)
      render json: @care_setting
    else
      render json: @care_setting.errors, status: :unprocessable_entity
    end
  end

  # DELETE /care_settings/1
  def destroy
    @care_setting.destroy
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_care_setting
    @care_setting = CareSetting.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def care_setting_params
    params.require(:care_setting).permit(:care_setting_id, :name, :description, :care_setting_type, :creator,
                                         :date_created, :retired, :retired_by, :date_retired, :retire_reason, :changed_by, :date_changed, :uuid)
  end
end
