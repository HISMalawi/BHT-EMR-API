# frozen_string_literal: true

require 'utils/remappable_hash'
require 'zebra_printer/init'

class Api::V1::LocationsController < ApplicationController
  skip_before_action :authenticate, only: %i[print_label]

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

  def print_label
    location = location_to_print

    unless location
      return render json: 'location_id or location_name required', status: :bad_request
    end

    commands = service.print_location_label(location)
    send_data(commands, type: 'application/label; charset=utf-8',
                        stream: false,
                        filename: "#{params[:id]}#{rand(10_000)}.lbl",
                        disposition: 'inline')
  end

  private

  def filter_locations_by_tag(locations, tag)
    location_tag_id = LocationTag.where('name like ?', "%#{tag}%")[0].id
    location_tag_maps = LocationTagMap.where location_tag_id: location_tag_id
    locations = locations.joins(:tag_maps).merge(location_tag_maps)
    locations
  end

  def location
    Location.find(params[:id])
  end

  def service
    LocationService.new
  end

  # Helper for print label method that returns a location to be printed
  def location_to_print
    if params[:location_id]
      Location.find(params[:location_id])
    elsif params[:location_name]
      Location.find_by_name(params[:location_name])
    end
  end
end
