class Api::V1::PersonNamesController < ApplicationController
  def show
    render json: PersonName.find(params[:id])
  end

  def index
    filters = params.permit(%i[given_name middle_name family_name person_id])

    # TODO: Paginate!!!
    if filters.empty?
      render json: PersonName.all
    else
      conds = params_to_query_conditions filters
      render json: PersonName.where(conds[0].join(' AND '), *conds[1])
    end
  end

  private

  def params_to_query_conditions(params)
    params.to_hash.each_with_object([[], []]) do |kv_pair, query_conds|
      k, v = kv_pair
      v.gsub!(/(^'|'$)/, '')
      query_conds[0] << "#{k} like ?"
      query_conds[1] << "#{v}%"
    end
  end
end
