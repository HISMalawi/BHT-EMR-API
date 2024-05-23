# frozen_string_literal: true

module Api
  module V1
    class ProgramWorkflowsController < ApplicationController
      def show
        workflow = ProgramWorkflow.find_by program_workflow_id: params[:id],
                                           program_id: params[:program_id]
        if workflow
          render json: workflow
        else
          render json: { errors: ["Workflow ##{params[:id]} for program ##{params[:program_id]}"] },
                 status: :not_found
        end
      end

      def index
        workflows = ProgramWorkflow.where program_id: params[:program_id]
        render json: paginate(workflows)
      end
    end
  end
end
