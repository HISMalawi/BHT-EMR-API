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
    name = params[:name]
    tag = params[:tag]

    locations = paginate(Location.order(:name))
    locations = locations.where('name like ?', "%#{name}%") unless name.blank?
    locations = filter_locations_by_tag locations, tag if tag

    render json: locations
  end

  # Retrieve single location by its id
  #
  # GET /locations/:id
  def show
    render json: Location.find(params[:id])
  end

  def create
    params.permit %i[name description address1 address2 district]

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
    location_tag_id = LocationTag.where('name like ?', "%#{tag}%")[0].id
    location_tag_maps = LocationTagMap.where location_tag_id: location_tag_id
    locations = locations.joins(:tag_maps).merge(location_tag_maps)
    locations
  end
end
