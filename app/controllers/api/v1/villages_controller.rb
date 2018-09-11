class Api::V1::VillagesController < ApplicationController
  def index
    filters = params.permit(:traditional_authority_id)

    if filters.empty?
      render json: paginate(Village.order(:name))
    else
      render json: paginate(Village.where(filters).order(:name))
    end
  end
end
