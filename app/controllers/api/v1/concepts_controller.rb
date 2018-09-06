class Api::V1::ConceptsController < ApplicationController
  def show
    render json: Concept.find(params[:id])
  end

  def index
    render json: paginate(Concept)
  end
end
