# frozen_string_literal: true

class Api::V1::DistrictsController < ApplicationController
  def create
    params = params.require(%i[name region_id])

    district = District.create(params)
    if district.errors.empty?
      render json: district, status: :created
    else
      render json: district.errors, status: :bad_request
    end
  end

  def index
    filters = params.permit(%i[region_id name district_id])

    if filters.empty?
      render json: paginate(District.order(:name))
    else
      inexact_filters = make_inexact_filters(filters, [:name])
      render json: paginate(District.where(*inexact_filters).order(:name))
    end
  end
end
