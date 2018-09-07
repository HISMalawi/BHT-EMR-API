class Api::V1::RegionsController < ApplicationController
  def index
    render json: paginate(Region)
  end
end
