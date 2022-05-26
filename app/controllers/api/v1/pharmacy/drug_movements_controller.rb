# frozen_string_literal: true

# rubocop:disable Style/ClassAndModuleChildren
# controller giving reports on drug movement
class Api::V1::Pharmacy::DrugMovementsController < ApplicationController
  # return an array of drug movement
  def show
    items = ARTService::Pharmacy::DrugMovement.stock_movement(allowed_params)

    render json: items, status: 200
  end

  private

  # these are the allowed params
  def allowed_params
    params.slice(:start_date, :end_date, :drug_id)
  end
end
# rubocop:enable Style/ClassAndModuleChildren
