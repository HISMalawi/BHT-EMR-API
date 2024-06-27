# frozen_string_literal: true

module Lab
  class ResultsController < ApplicationController
    def create
      result_params = params.require(:result)
                            .permit([:encounter_id,
                                     :date,
                                     { measures: [:value,
                                                  :value_type,
                                                  :value_modifier,
                                                  { indicator: [:concept_id] }] }])

      result = Lab::ResultsService.create_results(params[:test_id], result_params)

      render json: result, status: :created
    end
  end
end
