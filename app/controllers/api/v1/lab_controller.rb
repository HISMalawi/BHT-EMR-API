# frozen_string_literal: true

module Api
  module V1
    class LabController < ApplicationController
      # Dispatches any requests received to matching methods in the bound service
      #
      # Example:
      #   `GET programs/1/lab/random?foo=bar` -> ArtService::Lab.new().dispatch(params)
      def dispatch_request
        logger.info(params)

        logger.info([service, service.methods])
        method = service.method(params[:resource].to_sym)
        raise NotFoundError, "Resouce `#{params[:resource]}` not found in #{service.class}" unless method

        render json: method.call(params)
      end

      private

      def service
        LabService.new(program).load_engine
      end

      def program
        Program.find(params[:program_id])
      end
    end
  end
end
