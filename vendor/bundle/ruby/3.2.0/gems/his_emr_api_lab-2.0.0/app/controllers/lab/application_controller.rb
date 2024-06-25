# frozen_string_literal: true

module Lab
  class ApplicationController < ::ApplicationController
    before_action :permit_parameters

    def permit_parameters
      params.permit!
    end
  end
end
