# frozen_string_literal: true

class Api::V1::DistrictsController < ApplicationController
  def index
    filters = params.permit(%i[region_id name])

    if filters.empty?
      render json: paginate(District.order(:name))
    else
      inexact_filters = make_inexact_filters(filters, [:name])
      render json: paginate(District.where(*inexact_filters).order(:name))
    end
  end
end
