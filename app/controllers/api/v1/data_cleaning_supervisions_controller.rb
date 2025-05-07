# frozen_string_literal: true

module Api
  module V1
    # Data Cleaning Supervision Controller
    class DataCleaningSupervisionsController < ApplicationController
      before_action :set_data_cleaning, only: %i[show update destroy]

      def index
        render json: paginate(DataCleaningSupervision.all.order(data_cleaning_datetime: :desc))
      end

      def show
        render json: @data_cleaning_tool
      end

      def create
        data_supervision = DataCleaningSupervision.create!(data_cleaning_params)
        render json: data_supervision, status: :created
      end

      def update
        @data_cleaning_tool.update!(data_cleaning_params)
        render json: @data_cleaning_tool, status: :ok
      end

      def destroy
        reason = params.require(:reason)
        @data_cleaning_tool.void(reason)
        render json: { message: 'removed successfully' }, status: :ok
      end

      private

      def set_data_cleaning
        @data_cleaning_tool = DataCleaningSupervision.find(params[:id])
      end

      def data_cleaning_params
        params.permit(:data_cleaning_datetime, :supervisors, :comments)
      end
    end
  end
end
