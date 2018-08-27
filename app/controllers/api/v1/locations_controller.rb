class Api::V1::LocationsController < ApplicationController
  before_action :check_if_token_valid

  def regions

    regions = Region.all.collect{|d|
      [d.id, d.name]}

    if !regions.blank?
      render json: {
          status: 200,
          error: false,
          message: 'found',
          data: regions
      }
    else
      render json: {
          status: 401,
          error: true,
          message: 'regions could not be found',
          data: {}
      }
    end
  end

  def districts

    districts = District.where(region_id: params[:region_id]).order("name").collect{|d|
      [d.id, d.name]}

    if !districts.blank?
      render json: {
          status: 200,
          error: false,
          message: 'found',
          data: districts
      }
    else
      render json: {
          status: 401,
          error: true,
          message: 'districts could not be found',
          data: {}
      }
    end
  end

  def tas
    tas = TraditionalAuthority.where(district_id: params[:district_id]).order('name').collect{|t|
      [t.id, t.name]}

    if !tas.blank?
      render json: {
          status: 200,
          error: false,
          message: 'found',
          data: tas
      }
    else
      render json: {
          status: 401,
          error: true,
          message: 'traditional authorities could not be found',
          data: {}
      }
    end
  end

  def villages

    villages = Village.where(traditional_authority_id: params[:ta_id]).order('name').collect{|v|
      [v.id, v.name]}

    if !villages.blank?
      render json: {
          status: 200,
          error: false,
          message: 'found',
          data: villages
      }
    else
      render json: {
          status: 401,
          error: true,
          message: 'villages could not be found',
          data: {}
      }
    end
  end
end
