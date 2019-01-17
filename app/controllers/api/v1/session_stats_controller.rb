# frozen_string_literal: true

class Api::V1::SessionStatsController < ApplicationController
  def show
    render json: service.visits
  end

  private

  def service
    date = params.permit(%i[date])[:date]&.to_date || Date.today
    SessionStatsService.new User.current, date
  end
end
