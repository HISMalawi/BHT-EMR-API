class Api::V1::DrugsController < ApplicationController
  def index
    name = params.permit(:name)[:name]
    query = name ? Drug.where('name like ?', "%#{name}%") : Drug
    render json: paginate(query)
  end
end
