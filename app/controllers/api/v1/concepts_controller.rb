# frozen_string_literal: true

module Api
  module V1
    class ConceptsController < ApplicationController
      def show
        # TODO: Remove unscoped modifier below. This was added to enable reading of retired
        #       concepts some of which were still being used by existing applications.
        render json: Concept.unscoped.find(params[:id])
      end

      def index
        permitted_params = params.permit(:name, :set)
        name = permitted_params[:name]
        set = permitted_params[:set]

        query = Concept.all

        if name
          query = query.joins(:concept_names)
                       .merge(ConceptName.where(name:))
        end

        if set
          query = query.joins(:concept_sets)
                       .merge(ConceptSet.where(concept_set: Concept.find_by_name(set)))
        end

        render json: paginate(query)
      end
    end
  end
end
