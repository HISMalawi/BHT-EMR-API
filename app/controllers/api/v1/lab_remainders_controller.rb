# frozen_string_literal: true

module Api
  module V1
    class LabRemaindersController < ApplicationController
      def index
        render json: service.vl_reminder_info
      end

      private

      def service
        ArtService::VlReminder.new(patient_id: params[:program_patient_id],
                                   date: params[:date])
      end
    end
  end
end
