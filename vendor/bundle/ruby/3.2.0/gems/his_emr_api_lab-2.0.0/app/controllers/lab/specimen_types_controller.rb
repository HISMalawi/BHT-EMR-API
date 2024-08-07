# frozen_string_literal: true

module Lab
  class SpecimenTypesController < ApplicationController
    def index
      filters = params.slice(:name, :test_type)

      specimen_types = ConceptsService.specimen_types(name: filters['name'],
                                                      test_type: filters['test_type'])
                                      .as_json(only: %w[concept_id name])

      render json: specimen_types
    end
  end
end
