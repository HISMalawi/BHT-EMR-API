# frozen_string_literal: true

# controller for managing merge rollback
class Api::V1::RollbackController < ApplicationController
  def merge_history
    identifier = params.require(:identifier)
    render json: merge_service.get_patient_audit(identifier), status: :ok
  end

  def rollback_patient
    patient_id = params.require(:patient_id)
    program_id = params.require(:program_id)
    render json: rollback_service.rollback_merged_patient(patient_id, program_id), status: :ok
  end

  private

  def merge_service
    MergeAuditService.new
  end

  def rollback_service
    DDERollbackService.new
  end
end
