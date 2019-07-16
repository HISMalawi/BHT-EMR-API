class Api::V1::ConceptsController < ApplicationController
  def show
    # TODO: Remove unscoped modifier below. This was added to enable reading of retired
    #       concepts some of which were still being used by existing applications.
    render json: Concept.unscoped.find(params[:id])
  end

  def index
    name = params.permit(:name)[:name]
    concepts = name ? Concept.joins(:concept_names).where('name like ?', name) : Concept
    render json: paginate(concepts)
  end
end
