# frozen_string_literal: true

module Api
  module V1
    class LabTestLabelsController < ApplicationController
      skip_before_action :authenticate

      def print_order_label
        render_zpl(engine.print_order_label(params[:accession_number]))
      end

      private

      def engine
        LabTestService.load_engine(params[:program_id])
      end
    end
  end
end
