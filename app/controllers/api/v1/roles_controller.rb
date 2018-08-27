# frozen_string_literal: true

class Api::V1::RolesController < ApplicationController
  def index
    # TODO: Add pagination
    render json: Role.all
  end

  def show
    render json: Role.find(params[:id])
  end
end
