# frozen_string_literal: true

module Api
  module V1
    class PatientProgramsController < ApplicationController
      # TODO: Refactor much of the logic in this controller into a service

      def index
        filters = params.permit(%i[patient_id program_id])
        programs = filters.empty? ? PatientProgram.all : PatientProgram.where(filters)

        render json: paginate(programs)
      end

      def show
        render json: PatientProgram.find(params[:id])
      end

      def create
        create_params = params.require(:patient_program).permit(:program_id, :patient_id, :date_enrolled)
        create_params[:date_enrolled] ||= Time.now
        create_params[:location_id] = Location.current.id

        if program_exists?(program_id, patient_id)
          render json: { errors: ['Patient already enrolled in program'] }, status: :conflict

          return
        end

        new_patient_program = PatientProgram.create(create_params)

        if new_patient_program.errors.empty?
          render json: new_patient_program, status: :created
        else
          render json: new_patient_program.errors, status: :bad_request
        end
      end

      def destroy
        patient_program = PatientProgram.find_by(patient_program_id: params[:id])
        patient_program&.void(params[:reason] || "Voided by #{User.current.username}")

        if patient_program.nil? || patient_program.errors.empty?
          render status: :no_content
        else
          render json: :p_program.errors, status: :internal_server_error
        end
      end

      private

      def program_exists?(program_id, patient_id)
        PatientProgram.where(program_id:, patient_id:).exists?
      end
    end
  end
end
