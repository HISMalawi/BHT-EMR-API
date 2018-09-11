class Api::V1::TraditionalAuthoritiesController < ApplicationController
  def index
    filters = params.permit(%i[district_id name])

    if filters.empty?
      render json: paginate(TraditionalAuthority.order(:name))
    else
      inexact_filters = make_inexact_filters(filters, [:name])
      render json: paginate(TraditionalAuthority.where(*inexact_filters).order(:name))
    end
  end
end
