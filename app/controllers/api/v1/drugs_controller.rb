class Api::V1::DrugsController < ApplicationController
  def show
    render json: Drug.find(params[:id])
  end

  def index
    name = params.permit(:name)[:name]
    query = name ? Drug.where('name like ?', "#{name}%") : Drug
    render json: paginate(query)
  end
end
