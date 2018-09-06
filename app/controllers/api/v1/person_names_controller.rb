require "set"

class Api::V1::PersonNamesController < ApplicationController
  def show
    render json: PersonName.find(params[:id])
  end

  def index
    filters = params.permit(%i[given_name middle_name family_name person_id])

    # TODO: Paginate!!!
    if filters.empty?
      render json: paginate(PersonName)
    else
      conds = params_to_query_conditions filters
      render json: paginate(PersonName.where(conds[0].join(' AND '), *conds[1]))
    end
  end

  def search_given_name
    search_string = params.require('search_string')

    names = paginate(PersonName.where('given_name like ?', "#{search_string}%")).collect do |person_name|
      person_name.given_name
    end

    render json: Set.new(names)
  end

  def search_family_name
    search_string = params.require('search_string')

    names = paginate(PersonName.where('family_name like ?', "#{search_string}%")).collect do |person_name|
      person_name.family_name
    end

    render json: Set.new(names)
  end

  def search_middle_name
    search_string = params.require('search_string')

    names = paginate(PersonName.where('middle_name like ?', "#{search_string}%")).collect do |person_name|
      person_name.middle_name
    end

    render json: Set.new(names)
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
