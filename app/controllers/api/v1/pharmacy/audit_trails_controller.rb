# frozen_string_literal: true

class Api::V1::Pharmacy::AuditTrailsController < ApplicationController
  def show
    filters = params.permit(%i[start_date end_date drug_id batch_number])

    trail = audit_trail from: filters[:start_date],
                        to: filters[:end_date],
                        drug_id: filters[:drug_id],
                        batch_number: filters[:batch_number]

    render json: trail
  end

  private

  def audit_trail(**kwargs)
    ARTService::Pharmacy::AuditTrail.retrieve(**kwargs)
  end
end
