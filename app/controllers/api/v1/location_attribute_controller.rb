class Api::V1::LocationAttributeController < ApplicationController
  def show
    render json: LocationAttribute.where(location_id: params[:id])
  end
end
