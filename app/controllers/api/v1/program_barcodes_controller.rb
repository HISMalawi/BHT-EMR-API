# frozen_string_literal: true

module Api
  module V1
    class ProgramBarcodesController < ApplicationController
      before_action :authenticate, except: %i[print_barcode]

      def print_barcode
        barcode_name = params.require(:barcode_name)
        label_commands = service.send("#{barcode_name}_barcode", params)
        send_data label_commands, type: 'application/label; charset=utf-8',
                                  stream: false,
                                  filename: "#{barcode_name}-#{rand(10_000)}.lbl",
                                  disposition: 'inline'
      end

      private

      def service
        program = Program.find(params[:program_id] || params[:id])
        ProgramBarcodeService.new(program:)
      end
    end
  end
end
