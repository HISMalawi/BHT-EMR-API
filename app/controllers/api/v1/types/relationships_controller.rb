# frozen_string_literal: true

class Api::V1::Types::RelationshipsController < ApplicationController
  def index
    types = service.find search_string: params[:search_string]
    render json: paginate(types)
  end

  private

  def service
    @service ||= RelationshipTypeService.new
  end
end
