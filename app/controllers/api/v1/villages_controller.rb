class Api::V1::VillagesController < ApplicationController
  def create
    params = params.require(%i[name traditional_authority_id])

    village = Village.create(params)
    if village.errors.empty?
      render json: village, status: :created
    else
      render json: village.errors, status: :bad_request
    end
  end

  def index
    filters = params.permit(%i[traditional_authority_id name])

    if filters.empty?
      render json: paginate(Village.order(:name))
    else
      inexact_filters = make_inexact_filters(filters, [:name])
      render json: paginate(Village.where(*inexact_filters).order(:name))
    end
  end
end
