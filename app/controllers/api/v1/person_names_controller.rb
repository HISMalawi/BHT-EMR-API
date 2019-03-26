class Api::V1::PersonNamesController < ApplicationController
  def show
    render json: PersonName.find(params[:id])
  end

  def index
    filters = params.permit(%i[given_name middle_name family_name person_id])

    if filters.empty?
      render json: paginate(PersonName)
    else
      conds = params_to_query_conditions filters
      render json: paginate(PersonName.where(conds[0].join(' AND '), *conds[1]))
    end
  end

  def search_given_name
    search_partial_name :given_name
  end

  def search_family_name
    search_partial_name :family_name
  end

  def search_middle_name
    search_partial_name :middle_name
  end

  private

  def search_partial_name(field)
    search_string = params.require('search_string')

    query = PersonName.select(field).distinct.where("#{field} like ?", "#{search_string}%")
    query = paginate(query)

    render json: query.collect(&field)
  end

  def params_to_query_conditions(params)
    params.to_hash.each_with_object([[], []]) do |kv_pair, query_conds|
      k, v = kv_pair
      v.gsub!(/(^'|'$)/, '')
      query_conds[0] << "#{k} like ?"
      query_conds[1] << "#{v}%"
    end
  end
end
