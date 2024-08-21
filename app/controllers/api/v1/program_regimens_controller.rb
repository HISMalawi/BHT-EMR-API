# frozen_string_literal: true

module Api
  module V1
    # Program Regimens Controller
    class ProgramRegimensController < ApplicationController
      # GET /api/v1/program/{:program_id}/regimens
      def index
        if params[:patient_id]
          render json: service.find_regimens_by_patient(patient:)
        elsif params[:weight]
          use_tb_dosage = params[:tb_dosage]&.casecmp?('true')
          render json: service.find_regimens(patient_weight: params[:weight], use_tb_dosage:)
        else
          render json: { error: 'patient_id or weight required' }, status: :bad_request
        end
      end

      def get_tb_regimen_group
        patient, regimen_group = params.require(%i[patient regimen_group])
        regimens = service.get_tb_regimen_group patient, regimen_group
        render json: regimens
      end

      def find_starter_pack
        regimen, weight = params.require(%i[regimen weight])
        render json: service.find_starter_pack(regimen, weight)
      end

      def show
        regimen = params[:id]
        lpv_drug_type = params.require(:lpv_drug_type)

        render json: service.regimen(patient, regimen, lpv_drug_type:).values[0]
      end

      def custom_regimen_ingredients
        render json: service.custom_regimen_ingredients
      end

      def regimen_extras
        patient_weight = params.require(:weight)
        name = params[:name]

        render json: service.regimen_extras(patient_weight:, name:)
      end

      def custom_tb_ingredients
        render json: service.custom_regimen_ingredients(patient:)
      end

      private

      def patient(patient_id = nil)
        patient_id ||= params.require(:patient_id)
        Patient.find(patient_id)
      end

      def service
        program_id = params.require(:program_id)
        TbService::RegimenEngine.new(program: Program.find(program_id))
      end
    end
  end
end
