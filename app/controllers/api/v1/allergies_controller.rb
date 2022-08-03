class Api::V1::AllergiesController < ApplicationController
  before_action :set_allergy, only: %i[show update destroy]

  # GET /allergies
  def index
    @allergies = Allergy.all

    render json: @allergies
  end

  # GET /allergies/1
  def show
    render json: @allergy
  end

  # POST /allergies
  def create
    @allergy = Allergy.new(allergy_params)

    if @allergy.save
      render json: @allergy, status: :created
    else
      render json: @allergy.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /allergies/1
  def update
    if @allergy.update(allergy_params)
      render json: @allergy
    else
      render json: @allergy.errors, status: :unprocessable_entity
    end
  end

  # DELETE /allergies/1
  def destroy
    @allergy.destroy
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_allergy
    @allergy = Allergy.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def allergy_params
    params.require(:allergy).permit(:allergy_id, :patient_id, :severity_concept_id, :coded_allergen,
                                    :non_coded_allergen, :allergen_type, :comment, :creator, :date_created, :changed_by, :date_changed, :voided, :voided_by, :date_voided, :void_reason, :uuid)
  end
end
