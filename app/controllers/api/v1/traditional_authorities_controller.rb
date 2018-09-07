class Api::V1::TraditionalAuthoritiesController < ApplicationController
  def index
    filters = params.permit(:district_id)

    if filters.empty?
      render json: paginate(TraditionalAuthority)
    else
      render json: paginate(TraditionalAuthority.where(filters))
    end
  end
end
