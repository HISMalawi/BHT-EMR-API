class Api::V1::LocationController < Api::V1::BaseController
  #before_action :authenticate_user

  def districts

    districts = District.where(region_id: params[:region_id])
    render json: districts
  end

  def tas

  end

  def villages

  end

  private
end
