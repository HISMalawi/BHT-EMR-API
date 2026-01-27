# frozen_string_literal: true

module Api
  module V1
    class DistrictsController < ApplicationController
      def create
        params = params.require(%i[name region_id])

        district = District.create(params)
        if district.errors.empty?
          render json: district, status: :created
        else
          render json: district.errors, status: :bad_request
        end
      end

      def index
        filters = params.permit(%i[region_id name district_id])
        districts = District.all

        region_id, name, district_id = filters.values_at(:region_id, :name, :district_id)

        if region_id
          districts = districts.where(parent_location: region_id)
        end

        if name
          districts = districts.where('name like ?', "%#{name}%")
        end

        if district_id
          districts = districts.where(location_id: district_id)
        end

        render json: paginate(districts.order(:name))
      end
    end
  end
end
