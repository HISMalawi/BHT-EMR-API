# frozen_string_literal: true

module Api
  module V1
    module Programs
      module Patients
        class VisitController < ApplicationController
          def index
            permitted = params.permit(:date)
            date = permitted[:date]&.to_date || Date.today

            summary = service.patient_visit_summary(params[:program_patient_id], date)

            render json: summary
          end

          private

          def service
            ProgramServiceLoader
              .load(Program.find(params[:program_id]), 'PatientsEngine')
              .new
          end
        end
      end
    end
  end
end
