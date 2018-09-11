class Api::V1::VillagesController < ApplicationController
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
