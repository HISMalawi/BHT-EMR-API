class Api::V1::VillagesController < ApplicationController
  def index
    filters = params.permit(:traditional_authority_id)

    if filters.empty?
      render json: paginate(Village)
    else
      render json: paginate(Village.where(filters))
    end
  end
end
