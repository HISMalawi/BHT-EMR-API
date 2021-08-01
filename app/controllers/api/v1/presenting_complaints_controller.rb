class Api::V1::PresentingComplaintsController < ApplicationController

  def show
    render json: service.get_complaints(params[:id])
  end

  private

  def service
    PresentingComplaintService.new
  end
end
