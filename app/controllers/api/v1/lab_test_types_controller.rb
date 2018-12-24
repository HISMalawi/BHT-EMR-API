# frozen_string_literal: true

class Api::V1::LabTestTypesController < ApplicationController
  include LabTestsEngineLoader

  def index
    query = engine.types search_string: params[:search_string],
                         panel_id: params[:panel_id]

    # RANT: The following should really be happening on the frontend
    # when rendering. The backend should not be dictating presentation
    # of the data on the frontend. Besides we are unneccessarily wasting
    # cycles by doing it here as we have to loop through the `types` array
    # twice, first here and secondly in the following `render` call.
    types = paginate(query).collect do |type|
      type = type.as_json
      type['TestName'].gsub!(/_+/, ' ')
      type
    end

    render json: types
  end

  def panels
    query = engine.panels search_string: params[:search_string]
    render json: query
  end
end
