# frozen_string_literal: true

# Check that the database and other dependencies are available
class HealthcheckController < ApplicationController
  skip_before_action :authenticate

  def index
    ActiveRecord::Base.connection.execute('SELECT VERSION()')
    render json: { status: 'Up' }
  rescue StandardError => e
    logger.error "Database unreachable: #{e}"
    render json: { status: 'Down', error: 'Database unreachable' }
  end
end
