# frozen_string_literal: true

class Api::V1::LabTestTypesController < ApplicationController
  include LabTestsEngineLoader

  def index
    filters = params.permit(%i[search_string specimen_type])

    test_types = engine.types(name: filters[:search_string],
                              specimen_type: filters[:specimen_type])
                       .sort_by(&:name)
                       .map { |type| format_concept_name(type) }

    render json: test_types
  end

  def panels
    filters = params.permit(:test_type, :search_string)

    specimen_types = engine.panels(name: filters[:search_string],
                                   test_type: filters[:test_type])
                           .sort_by(&:name)
                           .map { |type| format_concept_name(type) }

    render json: specimen_types
  end

  def measures
    test_name = params.require(:test_name)
    render json: engine.test_measures(test_name)
  end

  private

  def format_concept_name(concept_name)
    {
      name: concept_name.name,
      concept_id: concept_name.concept_id
    }
  end
end
