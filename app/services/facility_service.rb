# frozen_string_literal: true

# app/services/facility_service.rb
class FacilityService
  def initialize(params = {})
    @params = params
  end

  # List all facilities with optional filters and sorting
  def list_facilities
    facilities = Location.includes(:location_attributes).all

    facilities = apply_name_filter(facilities)
    facilities = apply_district_filter(facilities)
    facilities = apply_district_name_filter(facilities)
    facilities = apply_location_filter(facilities)
    facilities = apply_sorting(facilities)

    {
      facilities: facilities,
      total: facilities.size,
      filters_applied: filters_applied
    }
  end

  # List all distinct districts
  def list_districts
    Location.select('city_village')
            .where.not(city_village: [nil, ''])
            .distinct
            .order(:city_village)
            .map.with_index do |location, index|
      {
        id: index + 1,
        name: location.city_village,
        display_name: location.city_village
      }
    end.compact
  end

  # Fetch facilities by district_name
  def list_facilities_by_district(district_name)
    sanitized_district_name = district_name.to_s.gsub('?', '')
    facilities = Location.includes(:location_attributes).all

    facilities = facilities.where(city_village: sanitized_district_name)

    {
      facilities: facilities,
      total: facilities.count,
      filters_applied: { district_name: sanitized_district_name }
    }
  end

  # Find nearby facilities from a given location
  def find_nearby_facilities(location_id)
    location = Location.find(location_id)
    radius = @params[:radius].present? ? @params[:radius].to_f : 10

    nearby = location.nearby_facilities(radius)
    nearby = filter_nearby_facilities(nearby)

    {
      facilities: nearby,
      total: nearby.size,
      center_facility: location
    }
  end

  # List all facility/location codes
  def list_facility_codes
    codes = Location.select('location_id, uuid')
                    .distinct
                    .order(:uuid)
                    .map do |location|
      {
        location_id: location.location_id,
        uuid: location.uuid,
        name: location.name
      }
    end.compact

    {
      facility_codes: codes,
      total: codes.size
    }
  end

  # Print location label using LocationService
  def print_location_label(location)
    LocationService.new.print_location_label(location)
  end

  private

  def apply_name_filter(facilities)
    return facilities unless @params[:name].present?

    name_query = "%#{@params[:name]}%"
    facilities.where('name LIKE ? OR description LIKE ?', name_query, name_query)
  end

  def apply_district_filter(facilities)
    return facilities unless @params[:city_village].present?

    facilities.where(city_village: @params[:city_village])
  end

  def apply_district_name_filter(facilities)
    return facilities unless @params[:district_name].present?

    district_query = "%#{@params[:district_name]}%"
    facilities.where('city_village LIKE ?', district_query)
  end

  def apply_location_filter(facilities)
    return facilities unless @params[:latitude].present? && @params[:longitude].present?

    radius = @params[:radius].present? ? @params[:radius].to_f : 10
    Location.search_by_coordinates(
      @params[:latitude],
      @params[:longitude],
      radius
    )
  end

  def apply_sorting(facilities)
    case @params[:sort_by]
    when 'name'
      facilities.order('name ASC')
    when 'district'
      facilities.order('city_village ASC, name ASC')
    when 'created'
      facilities.order('date_created DESC')
    else
      facilities.order('name ASC')
    end
  end

  def filter_nearby_facilities(facilities)
    facilities = filter_by_name(facilities)
    facilities = filter_by_district_name(facilities)
    facilities
  end

  def filter_by_name(facilities)
    return facilities unless @params[:name].present?

    facilities.select do |f|
      f.name.downcase.include?(@params[:name].downcase) ||
        (f.description && f.description.downcase.include?(@params[:name].downcase))
    end
  end

  def filter_by_district_name(facilities)
    return facilities unless @params[:district_name].present?

    district_query = @params[:district_name].downcase
    facilities.select { |f| f.city_village&.downcase&.include?(district_query) }
  end

  def filters_applied
    {
      name: @params[:name],
      district: @params[:city_village],
      district_name: @params[:district_name],
      latitude: @params[:latitude],
      longitude: @params[:longitude],
      radius: @params[:radius],
      sort_by: @params[:sort_by]
    }.compact
  end
end