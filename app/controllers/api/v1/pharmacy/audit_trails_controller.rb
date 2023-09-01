# frozen_string_literal: true

class Api::V1::Pharmacy::AuditTrailsController < ApplicationController
  def show
    filters = params.permit(%i[transaction_date drug_id batch_number transaction_reason])

    trail = drilled_audit_trail transaction_date: filters[:transaction_date],
                        drug_id: filters[:drug_id],
                        batch_number: filters[:batch_number],
                        transaction_reason: filters[:transaction_reason]

    render json: trail, status: :ok
  end

  def stock_report
    render json: service.stock_report, status: :ok
  end

  def show_grouped_audit_trail
    filters = params.permit(%i[start_date end_date transaction_date drug_id batch_number])

    trail = grouped_audit_trail from: filters[:start_date],
                        to: filters[:end_date],
                        transaction_date: filters[:transaction_date],
                        drug_id: filters[:drug_id],
                        batch_number: filters[:batch_number]

    render json: trail, status: :ok
  end

  private

  def drilled_audit_trail(**kwargs)
    service.retrieve_drilled_transactions(**kwargs)
  end

  def grouped_audit_trail(**kwargs)
    service.retrieve_grouped_transactions(**kwargs)
  end

  def service
    ARTService::Pharmacy::AuditTrail
  end
end
