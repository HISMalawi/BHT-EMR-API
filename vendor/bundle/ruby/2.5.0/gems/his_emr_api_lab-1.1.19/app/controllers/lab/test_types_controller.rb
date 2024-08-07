# frozen_string_literal: true

module Lab
  class TestTypesController < ApplicationController
    def index
      filters = params.permit(%w[name specimen_type])

      test_types = ConceptsService.test_types(name: filters['name'],
                                              specimen_type: filters['specimen_type'])
                                  .as_json(only: %w[concept_id name])

      render json: test_types
    end
  end
end
