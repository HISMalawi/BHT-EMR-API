class Api::V1::DistrictsController < ApplicationController
  def index
    filters = params.permit(:region_id)

    if filters.empty?
      render json: paginate(District)
    else
      render json: paginate(District.where(filters))
    end
  end
end
