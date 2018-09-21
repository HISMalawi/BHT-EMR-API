require 'utils/remappable_hash'

class Api::V1::LocationsController < ApplicationController
  # Retrieve all locations
  #
  # GET /locations
  #
  # Optional parameters (filters):
  #   name - Filter locations having this name
  #   tag - Filter locations having a tag matching this
  def index
    filters = params.permit(%i[name tag])
    filters.delete(:name) if filters[:name].blank?

    tag = filters.delete :tag
    locations = filters.empty? ? Location : Location.where(filters)
    locations = filter_locations_by_tag locations, tag if tag

    render json: paginate(locations)
  end

  # Retrieve single location by its id
  #
  # GET /locations/:id
  def show
    render json: Location.find(params[:id])
  end

  def create
    params.permit(%i[
      name description address1 address2 district
    ])
    location = Location.create(
      name: name,
      creator: User.current_user.id,
      date_created: Time.now
    )

    if location.errors
      render json: location.errors, status: :bad_request
    else
      render json: location
    end
  end

  private

  def filter_locations_by_tag(locations, tag)
    logger.debug tag
    location_tag_id = LocationTag.where('name like ?', "%#{tag}%")[0].id
    location_tag_maps = LocationTagMap.where location_tag_id: location_tag_id
    locations = locations.joins(:tag_maps).merge(location_tag_maps)
    locations
  end

  # def regions

  #   regions = Region.all.collect{|d|
  #     [d.id, d.name]}

  #   if !regions.blank?
  #     render json: {
  #         status: 200,
  #         error: false,
  #         message: 'found',
  #         data: regions
  #     }
  #   else
  #     render json: {
  #         status: 401,
  #         error: true,
  #         message: 'regions could not be found',
  #         data: {}
  #     }
  #   end
  # end

  # def districts

  #   districts = District.where(region_id: params[:region_id]).order("name").collect{|d|
  #     [d.id, d.name]}

  #   if !districts.blank?
  #     render json: {
  #         status: 200,
  #         error: false,
  #         message: 'found',
  #         data: districts
  #     }
  #   else
  #     render json: {
  #         status: 401,
  #         error: true,
  #         message: 'districts could not be found',
  #         data: {}
  #     }
  #   end
  # end

  # def tas
  #   tas = TraditionalAuthority.where(district_id: params[:district_id]).order('name').collect{|t|
  #     [t.id, t.name]}

  #   if !tas.blank?
  #     render json: {
  #         status: 200,
  #         error: false,
  #         message: 'found',
  #         data: tas
  #     }
  #   else
  #     render json: {
  #         status: 401,
  #         error: true,
  #         message: 'traditional authorities could not be found',
  #         data: {}
  #     }
  #   end
  # end

  # def villages

  #   villages = Village.where(traditional_authority_id: params[:ta_id]).order('name').collect{|v|
  #     [v.id, v.name]}

  #   if !villages.blank?
  #     render json: {
  #         status: 200,
  #         error: false,
  #         message: 'found',
  #         data: villages
  #     }
  #   else
  #     render json: {
  #         status: 401,
  #         error: true,
  #         message: 'villages could not be found',
  #         data: {}
  #     }
  #   end
  # end
end
