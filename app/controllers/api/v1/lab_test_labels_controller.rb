# frozen_string_literal: true

module Api
  module V1
    class LabTestLabelsController < ApplicationController
      skip_before_action :authenticate

      def print_order_label
        commands = engine.print_order_label(params[:accession_number])
        send_data(commands, type: 'application/label; charset=utf-8',
                            stream: false,
                            filename: "#{SecureRandom.hex(24)}.lbl",
                            disposition: 'inline')
      end

      private

      def engine
        LabTestService.load_engine(params[:program_id])
      end
    end
  end
end
