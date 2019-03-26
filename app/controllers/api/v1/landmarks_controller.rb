class Api::V1::LandmarksController < ApplicationController
  def search
    query = PersonAddress.where('address1 IS NOT NULL')
    query = query.where 'address1 like ?', "#{params[:search_string]}%" if params[:search_string]
    query = query.order(:address1).group(:address1)
    render json: paginate(query).collect(&:address1)
  end
end
