# frozen_string_literal: true

class Api::V1::RolesController < ApplicationController
  def index
    render json: paginate(Role)
  end

  def show
    render json: Role.find(params[:id])
  end
end
