# frozen_string_literal: true

module Api
  module V1
    module Patients
      class ProgramsController < ApplicationController
        # TODO: Refactor much of the logic in this controller into a service

        after_action :immunization_cache_update, only: [:create]

        def index
          render json: PatientProgram.where(patient_id: params[:patient_id])
        end

        def show
          render json: patient_program!
        end

        def create
          create_params = params.permit(:program_id, :date_enrolled)
          create_params[:date_enrolled] ||= Time.now
          create_params[:location_id] = Location.current.id
          create_params[:patient_id] = params[:patient_id]

          if PatientProgram.where(program_id: params[:program_id], patient_id: params[:patient_id])
                           .exists?
            render json: { errors: ['Patient already enrolled in program'] },
                   status: :conflict
            return
          end

          new_patient_program = PatientProgram.create(create_params)

          if new_patient_program.errors.empty?
            render json: new_patient_program, status: :created
          else
            render json: new_patient_program.errors, status: :bad_request
          end
        end

        def update
          p_program = patient_program!
          date_enrolled = params.require(:date_enrolled)

          if p_program.update(date_enrolled:, location_id: Location.current.id)
            render json: p_program
          else
            render json: { errors: p_program.errors }, status: :bad_request
          end
        end

        def destroy
          p_program = patient_program

          if p_program.nil? || p_program.destroy
            render status: :no_content
          else
            render json: :p_program.errors, status: :internal_server_error
          end
        end

        private

        def patient_program
          PatientProgram.find_by(patient_id: params[:patient_id], program_id: params[:id])
        end

        def patient_program!
          PatientProgram.find_by!(patient_id: params[:patient_id], program_id: params[:id])
        end

        def immunization_cache_update
          # Update Immunization Data Cache
          start_date = 1.year.ago.to_date.to_s
          end_date = Date.today.to_s

          location_id = User.current.location_id

          ImmunizationReportJob.perform_later(start_date, end_date, location_id)
          DashboardStatsJob.perform_later(location_id)
        end
      end
    end
  end
end
