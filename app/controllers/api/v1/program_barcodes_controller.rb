# frozen_string_literal: true

module Api
  module V1
    class ProgramBarcodesController < ApplicationController
      before_action :authenticate, except: %i[print_barcode]

      def print_barcode
        barcode_name = params.require(:barcode_name)
        label_commands = service.send("#{barcode_name}_barcode", params)
        render_zpl(label_commands)
      end

      private

      def service
        program = Program.find(params[:program_id] || params[:id])
        ProgramBarcodeService.new(program:)
      end
    end
  end
end
