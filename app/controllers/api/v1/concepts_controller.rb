class Api::V1::ConceptsController < ApplicationController
  def show
    render json: Concept.find(params[:id])
  end

  def index
    name = params.permit(:name)[:name]
    concepts = name ? Concept.joins(:concept_names).where('name like ?', name) : Concept
    render json: paginate(concepts)
  end
end
