class Api::V1::AllergyReactionsController < ApplicationController
  before_action :set_allergy_reaction, only: %i[show update destroy]

  # GET /allergy_reactions
  def index
    @allergy_reactions = AllergyReaction.all

    render json: @allergy_reactions
  end

  # GET /allergy_reactions/1
  def show
    render json: @allergy_reaction
  end

  # POST /allergy_reactions
  def create
    @allergy_reaction = AllergyReaction.new(allergy_reaction_params)

    if @allergy_reaction.save
      render json: @allergy_reaction, status: :created
    else
      render json: @allergy_reaction.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /allergy_reactions/1
  def update
    if @allergy_reaction.update(allergy_reaction_params)
      render json: @allergy_reaction
    else
      render json: @allergy_reaction.errors, status: :unprocessable_entity
    end
  end

  # DELETE /allergy_reactions/1
  def destroy
    @allergy_reaction.destroy
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_allergy_reaction
    @allergy_reaction = AllergyReaction.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def allergy_reaction_params
    params.require(:allergy_reaction).permit(:allergy_reaction_id, :allergy_id, :reaction_concept_id,
                                             :reaction_non_coded, :uuid)
  end
end
