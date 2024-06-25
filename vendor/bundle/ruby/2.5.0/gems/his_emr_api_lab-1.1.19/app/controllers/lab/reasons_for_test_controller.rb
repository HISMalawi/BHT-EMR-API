# frozen_string_literal: true

module Lab
  class ReasonsForTestController < ApplicationController
    def index
      render json: ConceptsService.reasons_for_test
    end
  end
end
